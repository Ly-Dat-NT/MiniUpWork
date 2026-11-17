"use strict";

const registration = byId("register-form");
const newJob = byId("new-job");
const skillForm = byId("edit-skills");
const manageFeedback = byId("manage-message");
const jobSkills = byId("job-skills");
const dialog = byId("manage-dialog");
const dialogForm = byId("manage-dialog-form");
const dialogFields = byId("manage-dialog-fields");
let jobSkillCatalog = [];
let profileSkills = [];
let displayedJob = null;

function sendJson(path, body, method = "POST") {
  const options = { method };
  if (body !== undefined) Object.assign(options, { headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  return request(path, options);
}

function toggleFields(form, entries) {
  for (const [field, label, enabled] of entries) {
    const control = form.elements[field];
    byId(label).hidden = !enabled;
    control.disabled = !enabled;
    control.required = enabled;
  }
}

registration.elements.role.addEventListener("change", () => {
  const role = registration.elements.role.value;
  toggleFields(registration, [
    ["company_name", "register-company", role !== "FREELANCER"],
    ["headline", "register-headline", role !== "CLIENT"],
    ["hourly_rate", "register-rate", role !== "CLIENT"],
  ]);
});
registration.elements.role.dispatchEvent(new Event("change"));
registration.addEventListener("submit", async (event) => {
  event.preventDefault();
  const body = Object.fromEntries(new FormData(registration));
  const submit = registration.querySelector("button[type=submit]");
  submit.disabled = true;
  try {
    await sendJson("/register", body);
    registration.reset();
    registration.elements.role.dispatchEvent(new Event("change"));
    byId("registration").open = false;
    byId("username").value = body.username;
    notice(byId("login-message"), "Đã tạo tài khoản. Nhập mật khẩu để đăng nhập.", "success");
  } catch (error) {
    notice(byId("register-message"), error.code === "duplicate_record" ? "Tên đăng nhập hoặc email đã có người dùng."
      : "Kiểm tra họ tên, email và các trường của vai trò bạn chọn.", "error");
  } finally {
    submit.disabled = false;
  }
});

function catalogSelect(select, rows, id, label) {
  select.replaceChildren(new Option("Chọn…", ""), ...rows.map((row) => new Option(row[label], String(row[id]))));
}

async function loadManagement() {
  const user = state.user;
  if (!user) return;
  byId("client-tools").hidden = !user.is_client;
  byId("freelancer-tools").hidden = !user.is_freelancer;
  for (const id of ["own-jobs", "applicants", "own-proposals", "own-skills"]) byId(id).replaceChildren();
  displayedJob = null;
  byId("applicants-title").textContent = "Đề xuất cho tin";
  notice(manageFeedback, "Đang tải công việc của bạn…");
  try {
    const catalog = state.catalog || await request("/reference-data");
    if (state.user !== user) return;
    catalogSelect(newJob.elements.category_id, categoryChoices(catalog.categories), "category_id", "category_name");
    jobSkillCatalog = catalog.skills;
    const selected = newJob.querySelectorAll("[name=skill_id]");
    for (const element of [...selected, skillForm.elements.skill_id]) {
      const previous = element.value;
      catalogSelect(element, catalog.skills, "skill_id", "skill_name");
      element.value = previous;
    }
    await Promise.all([loadProfiles(user), user.is_client && loadOwnJobs(user), user.is_freelancer && loadFreelancer(user)]);
    if (state.user === user) notice(manageFeedback);
  } catch (error) {
    if (state.user === user) notice(manageFeedback, error.publicMessage || "Không thể tải dữ liệu quản lý.", "error");
  }
}

function managedAction(label, path, body, after, method = "POST") {
  return { label, run: async (event) => {
    const button = event.currentTarget;
    button.disabled = true;
    const user = state.user;
    try {
      await sendJson(path, body, method);
      if (state.user === user) {
        await after();
        notice(manageFeedback, "Đã lưu thay đổi.", "success");
      }
    } catch (error) {
      if (state.user === user) notice(manageFeedback, error.publicMessage || "Chưa thể lưu thay đổi.", "error");
    } finally {
      button.disabled = false;
    }
  } };
}

async function loadOwnJobs(user = state.user) {
  const jobs = await request("/me/jobs");
  if (state.user !== user) return;
  const rows = jobs.map((job) => {
    const path = `/me/jobs/${job.job_id}`;
    const actions = [{ label: "Xem đề xuất", run: () => loadApplicants(job) }];
    const choices = job.status === "DRAFT" ? [["open", "Mở tin"], ["cancel", "Hủy tin"]]
      : job.status === "OPEN" ? [["close", "Đóng tin"], ["cancel", "Hủy tin"]] : [];
    for (const [key, label] of choices) actions.push(managedAction(label, `${path}/${key}`, undefined, () => loadOwnJobs(user)));
    return summaryRow(job.title, `#${job.job_id} · ${job.proposal_count} đề xuất`, statusNames[job.status] || job.status, actions);
  });
  byId("own-jobs").replaceChildren(...rows);
  if (!rows.length) byId("own-jobs").append(textElement("li", "contract-meta", "Bạn chưa có tin tuyển dụng."));
}

async function loadApplicants(job) {
  const user = state.user;
  displayedJob = job.job_id;
  byId("applicants-title").textContent = `Đề xuất cho tin #${job.job_id}`;
  byId("applicants").replaceChildren();
  try {
    const rows = await request(`/me/jobs/${job.job_id}/proposals`);
    if (state.user !== user || displayedJob !== job.job_id) return;
    const list = rows.map((proposal) => {
      const actions = [];
      if (job.status === "OPEN" && ["SUBMITTED", "SHORTLISTED"].includes(proposal.status)) {
        const choices = proposal.status === "SUBMITTED" ? [["SHORTLISTED", "Chọn lọc"]] : [];
        choices.push(["REJECTED", "Từ chối"]);
        for (const [status, label] of choices) {
          actions.push(managedAction(label, `/me/proposals/${proposal.proposal_id}/decision`, { status }, () => loadApplicants(job)));
        }
        actions.push({ label: "Tạo hợp đồng", run: () => planContract(job, proposal) });
      }
      return summaryRow(`${proposal.full_name} · ${usd.format(proposal.offered_amount)}`, proposal.cover_letter,
        statusNames[proposal.status] || proposal.status, actions);
    });
    byId("applicants").replaceChildren(...list);
    if (!list.length) byId("applicants").append(textElement("li", "contract-meta", "Tin này chưa có đề xuất."));
  } catch (error) {
    if (state.user === user) notice(manageFeedback, error.publicMessage || "Chưa đọc được đề xuất.", "error");
  }
}

newJob.elements.job_type.addEventListener("change", () => {
  const hourly = newJob.elements.job_type.value === "HOURLY";
  toggleFields(newJob, [["max_rate", "max-rate", hourly]]);
  byId("new-price-label").textContent = hourly ? "Đơn giá tối thiểu (USD/giờ)" : "Ngân sách (USD)";
});
newJob.elements.job_type.dispatchEvent(new Event("change"));
newJob.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.user?.is_client) return;
  const fields = new FormData(newJob);
  const data = Object.fromEntries(fields);
  const levels = fields.getAll("required_level");
  const skills = fields.getAll("skill_id").map((skill, index) =>
    ({ skill_id: Number(skill), required_level: Number(levels[index]) }));
  if (new Set(skills.map(({ skill_id }) => skill_id)).size !== skills.length) {
    notice(manageFeedback, "Mỗi kỹ năng chỉ được chọn một lần.", "error");
    return;
  }
  const body = { client_id: state.user.user_id, title: data.title, description: data.description,
    category_id: Number(data.category_id), job_type: data.job_type, skills };
  if (data.job_type === "HOURLY") Object.assign(body, { rate_min: data.amount, rate_max: data.max_rate });
  else body.budget_amount = data.amount;
  const submit = newJob.querySelector("button[type=submit]");
  submit.disabled = true;
  try {
    await sendJson("/me/jobs", body);
    newJob.reset();
    while (jobSkills.children.length > 1) jobSkills.lastElementChild.remove();
    newJob.elements.job_type.dispatchEvent(new Event("change"));
    await loadOwnJobs();
    notice(manageFeedback, "Đã lưu bản nháp. Chọn Mở tin khi muốn nhận đề xuất.", "success");
  } catch (error) {
    notice(manageFeedback, error.publicMessage || "Kiểm tra các trường của tin tuyển dụng.", "error");
  } finally {
    submit.disabled = false;
  }
});

async function loadFreelancer(user = state.user) {
  const [proposals, profile] = await Promise.all([request("/me/proposals"), request(`/freelancers/${user.user_id}`)]);
  if (state.user !== user) return;
  const rows = proposals.map((p) => {
    const actions = [];
    if (["SUBMITTED", "SHORTLISTED"].includes(p.status)) {
      actions.push(managedAction("Rút đề xuất", `/me/proposals/${p.proposal_id}/withdraw`, undefined, () => loadFreelancer(user)));
    }
    if (p.job_status === "OPEN" && ["SUBMITTED", "WITHDRAWN"].includes(p.status)) {
      const label = p.status === "WITHDRAWN" ? "Nộp lại" : "Sửa đề xuất";
      actions.push({ label, run: () => editOffer(p, label) });
    }
    return summaryRow(p.title, `#${p.proposal_id} · ${usd.format(p.offered_amount)}`, statusNames[p.status] || p.status, actions);
  });
  byId("own-proposals").replaceChildren(...rows);
  if (!rows.length) byId("own-proposals").append(textElement("li", "contract-meta", "Bạn chưa gửi đề xuất."));
  profileSkills = profile.skills;
  byId("profile-rating").textContent = profile.review_count ? `${profile.avg_rating}/5 · ${profile.review_count} đánh giá` : "Chưa có đánh giá.";
  byId("own-skills").replaceChildren(...profile.skills.map((skill) => summaryRow(skill.skill_name, `Mức ${skill.proficiency_level}`, "",
    { label: "Bỏ kỹ năng", run: () => saveSkills(profileSkills.filter((row) => row.skill_id !== skill.skill_id)) })));
}

async function saveSkills(rows) {
  try {
    await sendJson("/me/skills", { skills: rows.map(({ skill_id, proficiency_level }) => ({ skill_id, proficiency_level })) }, "PUT");
    await loadFreelancer();
    notice(manageFeedback, "Đã cập nhật kỹ năng.", "success");
  } catch (error) {
    notice(manageFeedback, error.publicMessage || "Chưa thể cập nhật kỹ năng.", "error");
  }
}

skillForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const id = Number(skillForm.elements.skill_id.value);
  const level = Number(skillForm.elements.proficiency_level.value);
  saveSkills([...profileSkills.filter((row) => row.skill_id !== id), { skill_id: id, proficiency_level: level }]);
});

byId("add-job-skill").addEventListener("click", () => {
  if (jobSkills.children.length >= jobSkillCatalog.length) return;
  const row = jobSkills.firstElementChild.cloneNode(true);
  const select = row.querySelector("select");
  catalogSelect(select, jobSkillCatalog, "skill_id", "skill_name");
  row.querySelector("input").value = "3";
  const remove = textElement("button", "button button-outline", "Bỏ dòng");
  remove.type = "button";
  remove.addEventListener("click", () => row.remove());
  row.append(remove);
  jobSkills.append(row);
  select.focus();
});

async function loadProfiles(user) {
  const profiles = await request("/me/profile");
  if (state.user !== user) return;
  for (const role of ["client", "freelancer"]) {
    if (!profiles[role]) continue;
    const form = byId(`${role}-profile`);
    for (const [name, value] of Object.entries(profiles[role])) form.elements[name].value = value ?? "";
  }
}

for (const [role, optional] of [["client", "billing_address"], ["freelancer", "experience_level"]]) {
  const form = byId(`${role}-profile`);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const body = Object.fromEntries(new FormData(form));
    body[optional] = body[optional].trim() || null;
    await managedAction("Lưu hồ sơ", `/me/profile/${role}`, body, () => loadProfiles(state.user), "PUT")
      .run({ currentTarget: event.submitter });
  });
}

function dialogField(name, label, attributes = {}) {
  const field = document.createElement("label");
  const input = document.createElement(attributes.multiline ? "textarea" : "input");
  const { multiline, ...settings } = attributes;
  Object.assign(input, { name, required: true }, settings);
  field.append(label, input);
  return field;
}

function openManageDialog(title, fields, save) {
  const message = byId("manage-dialog-message");
  const submit = byId("manage-dialog-submit");
  const user = state.user;
  byId("manage-dialog-title").textContent = title;
  dialogFields.replaceChildren(...fields);
  notice(message);
  dialogForm.onsubmit = async (event) => {
    event.preventDefault();
    if (state.user !== user) { dialog.close(); return; }
    submit.disabled = true;
    try {
      await save(new FormData(dialogForm));
      dialog.close();
      if (state.user === user) notice(manageFeedback, "Đã lưu thay đổi.", "success");
    } catch (error) {
      notice(message, error.publicMessage || "Kiểm tra dữ liệu rồi thử lại.", "error");
    } finally {
      submit.disabled = false;
    }
  };
  dialog.showModal();
}

byId("close-manage-dialog").addEventListener("click", () => dialog.close());

function editOffer(proposal, label) {
  const withdrawn = proposal.status === "WITHDRAWN";
  const fields = [
    dialogField("cover_letter", "Lời giới thiệu", { multiline: true, maxLength: 5000, value: proposal.cover_letter }),
    dialogField("offered_amount", "Giá đề xuất (USD)", { type: "number", min: "0.01", step: "0.01", value: proposal.offered_amount }),
  ];
  openManageDialog(label, fields, async (data) => {
    await sendJson(`/me/proposals/${proposal.proposal_id}${withdrawn ? "/resubmit" : ""}`,
      Object.fromEntries(data), withdrawn ? "POST" : "PUT");
    await loadFreelancer();
  });
}

function planContract(job, proposal) {
  const hourly = job.job_type === "HOURLY";
  const plan = document.createElement("div");
  const fields = [textElement("p", "contract-meta",
    hourly ? `Đơn giá ${usd.format(proposal.offered_amount)}/giờ` : `Giá đã đề xuất ${usd.format(proposal.offered_amount)}`), plan];
  if (hourly) {
    plan.append(dialogField("weekly_limit", "Giới hạn giờ mỗi tuần", { type: "number", min: "1", max: "168" }));
  } else {
    const appendMilestone = () => {
      const row = document.createElement("fieldset");
      row.append(textElement("legend", "", "Mốc bàn giao"),
        dialogField("title", "Tên mốc", { maxLength: 200 }),
        dialogField("amount", "Số tiền (USD)", { type: "number", min: "0.01", step: "0.01",
          value: plan.childElementCount ? "" : proposal.offered_amount }),
        dialogField("due_date", "Hạn nộp", { type: "date" }));
      if (plan.childElementCount) {
        const remove = textElement("button", "button button-outline", "Bỏ mốc");
        remove.type = "button";
        remove.addEventListener("click", () => row.remove());
        row.append(remove);
      }
      plan.append(row);
    };
    appendMilestone();
    const add = textElement("button", "button button-outline", "Thêm mốc");
    add.type = "button";
    add.addEventListener("click", () => { if (plan.childElementCount < 50) appendMilestone(); });
    fields.push(add);
  }
  openManageDialog("Tạo hợp đồng", fields, async (data) => {
    const body = { status: "ACCEPTED", expected_offered_amount: proposal.offered_amount };
    if (hourly) body.weekly_limit = Number(data.get("weekly_limit"));
    else {
      const amounts = data.getAll("amount");
      const dates = data.getAll("due_date");
      body.milestones = data.getAll("title").map((title, index) =>
        ({ title, amount: amounts[index], due_date: dates[index] }));
    }
    await sendJson(`/me/proposals/${proposal.proposal_id}/decision`, body);
    await loadOwnJobs();
    await loadApplicants({ ...job, status: "CLOSED" });
  });
}
