"use strict";

const registration = byId("register-form");
const newJob = byId("new-job");
const manageFeedback = byId("manage-message");
const jobSkills = byId("new-job-skills");
const composer = byId("job-composer");
const dialog = byId("manage-dialog");
const dialogForm = byId("manage-dialog-form");
const dialogFields = byId("manage-dialog-fields");
let jobSkillCatalog = [];
let ownJobs = [];
let jobFilter = "ALL";
let displayedJob = null;

function proposalStatus(status) {
  return status === "SUBMITTED" ? "Đã gửi đề xuất" : statusNames[status] || status;
}

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

function clearApplicants() {
  displayedJob = null;
  byId("applicants-title").textContent = "Đề xuất";
  byId("applicants").replaceChildren();
  notice(byId("applicants-message"), "Chọn một tin để xem đề xuất.");
}

function resetManagement() {
  newJob.reset();
  while (jobSkills.children.length > 1) jobSkills.lastElementChild.remove();
  newJob.elements.job_type.dispatchEvent(new Event("change"));
  composer.hidden = true;
  ownJobs = [];
  jobFilter = "ALL";
  jobSkillCatalog = [];
  for (const id of ["hiring-open", "hiring-draft", "hiring-proposals"]) byId(id).textContent = "—";
  byId("own-jobs").replaceChildren();
  byId("own-proposals").replaceChildren();
  clearApplicants();
  if (dialog.open) dialog.close();
}

async function loadManagement() {
  const user = state.user;
  const mode = state.mode;
  const hiring = mode === "client";
  byId("client-tools").hidden = !hiring;
  byId("freelancer-tools").hidden = hiring;
  byId("own-jobs").replaceChildren();
  byId("own-proposals").replaceChildren();
  clearApplicants();
  notice(manageFeedback, "Đang tải…");
  try {
    if (hiring) {
      const catalog = state.catalog || await request("/reference-data");
      if (!inManagement(user, mode)) return;
      const category = newJob.elements.category_id;
      const previousCategory = category.value;
      catalogSelect(category, categoryChoices(catalog.categories), "category_id", "category_name");
      category.value = previousCategory;
      jobSkillCatalog = catalog.skills;
      for (const element of newJob.querySelectorAll("[name=skill_id]")) {
        const previousSkill = element.value;
        catalogSelect(element, catalog.skills, "skill_id", "skill_name");
        element.value = previousSkill;
      }
      await loadOwnJobs(user);
    } else {
      await loadFreelancer(user);
    }
    if (inManagement(user, mode)) notice(manageFeedback);
  } catch (error) {
    if (inManagement(user, mode)) notice(manageFeedback, error.publicMessage || "Không thể tải dữ liệu quản lý.", "error");
  }
}

function inManagement(user, mode) {
  return state.user === user && state.mode === mode && state.section === "manage";
}

function managedAction(label, path, body, after, method = "POST") {
  return { label, run: async (event) => {
    const button = event.currentTarget;
    button.disabled = true;
    const user = state.user;
    const mode = state.mode;
    try {
      const result = await sendJson(path, body, method);
      if (inManagement(user, mode)) {
        const message = await after(result);
        if (inManagement(user, mode)) notice(manageFeedback, message || "Đã lưu thay đổi.", "success");
      }
    } catch (error) {
      if (inManagement(user, mode)) notice(manageFeedback, error.publicMessage || "Chưa thể lưu thay đổi.", "error");
    } finally {
      button.disabled = false;
    }
  } };
}

async function loadOwnJobs(user = state.user) {
  const jobs = await request("/me/jobs");
  if (!inManagement(user, "client")) return;
  ownJobs = jobs;
  const open = ownJobs.filter((job) => job.status === "OPEN");
  byId("hiring-open").textContent = integers.format(open.length);
  byId("hiring-draft").textContent = integers.format(ownJobs.filter((job) => job.status === "DRAFT").length);
  byId("hiring-proposals").textContent = integers.format(open.reduce((sum, job) => sum + job.proposal_count, 0));
  renderOwnJobs();
}

function renderOwnJobs() {
  const visible = ownJobs.filter((job) => jobFilter === "ALL" || job.status === jobFilter
    || (jobFilter === "CLOSED" && job.status === "CANCELLED"));
  for (const button of byId("job-status-filters").querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.jobState === jobFilter));
  }
  const rows = visible.map((job) => {
    const path = `/me/jobs/${job.job_id}`;
    const actions = [{ label: "Xem đề xuất", run: () => loadApplicants(job, true) }];
    if (job.status === "CLOSED") {
      actions.push(managedAction("Đăng lại", `${path}/repost`, undefined, async (reposted) => {
        clearApplicants();
        jobFilter = "OPEN";
        await loadOwnJobs();
        return `Đã đăng lại thành tin #${reposted.job_id}. Tin đang nhận đề xuất.`;
      }));
    }
    const choices = job.status === "DRAFT" ? [["open", "Mở tin"], ["cancel", "Hủy tin"]]
      : job.status === "OPEN" ? [["close", "Đóng tin"], ["cancel", "Hủy tin"]] : [];
    for (const [key, label] of choices) {
      actions.push(managedAction(label, `${path}/${key}`, undefined, async () => {
        const current = state.user;
        await loadOwnJobs(current);
        if (inManagement(current, "client") && displayedJob === job.job_id) {
          const updated = ownJobs.find((row) => row.job_id === job.job_id);
          if (updated) await loadApplicants(updated);
        }
      }));
    }
    return summaryRow(job.title, `#${job.job_id} · ${typeName(job)} · ${job.proposal_count} đề xuất`, statusNames[job.status] || job.status, actions);
  });
  byId("own-jobs").replaceChildren(...rows);
  if (!rows.length) byId("own-jobs").append(textElement("li", "contract-meta",
    jobFilter === "ALL" ? "Bạn chưa có tin tuyển dụng." : "Chưa có tin ở trạng thái này."));
}

async function loadApplicants(job, focus = false) {
  const user = state.user;
  displayedJob = job.job_id;
  const heading = byId("applicants-title");
  heading.textContent = job.title;
  byId("applicants").replaceChildren();
  notice(byId("applicants-message"), "Đang tải đề xuất…");
  if (focus) heading.focus();
  try {
    const rows = await request(`/me/jobs/${job.job_id}/proposals`);
    if (!inManagement(user, "client") || displayedJob !== job.job_id) return;
    const list = rows.map((proposal) => {
      const actions = [{ label: "Xem hồ sơ", run: () => showApplicantProfile(proposal.freelancer_id) }];
      if (job.status === "OPEN" && ["SUBMITTED", "SHORTLISTED"].includes(proposal.status)) {
        const choices = proposal.status === "SUBMITTED" ? [["SHORTLISTED", "Chọn lọc"]] : [];
        choices.push(["REJECTED", "Từ chối"]);
        for (const [status, label] of choices) {
          actions.push(managedAction(label, `/me/proposals/${proposal.proposal_id}/decision`, { status }, () => loadApplicants(job)));
        }
        actions.push({ label: "Tạo hợp đồng", run: () => planContract(job, proposal) });
      }
      return summaryRow(`${proposal.full_name} · ${usd.format(proposal.offered_amount)}`, proposal.cover_letter,
        proposalStatus(proposal.status), actions);
    });
    byId("applicants").replaceChildren(...list);
    notice(byId("applicants-message"), list.length ? "" : "Tin này chưa có đề xuất.");
  } catch (error) {
    if (inManagement(user, "client") && displayedJob === job.job_id) {
      notice(byId("applicants-message"), error.publicMessage || "Chưa đọc được đề xuất.", "error");
    }
  }
}

for (const button of byId("job-status-filters").querySelectorAll("button")) {
  button.addEventListener("click", () => {
    jobFilter = button.dataset.jobState;
    renderOwnJobs();
  });
}

byId("post-job").addEventListener("click", () => {
  composer.hidden = false;
  newJob.elements.title.focus();
});
byId("hide-composer").addEventListener("click", () => {
  composer.hidden = true;
  byId("post-job").focus();
});

newJob.elements.job_type.addEventListener("change", () => {
  const hourly = newJob.elements.job_type.value === "HOURLY";
  toggleFields(newJob, [["max_rate", "max-rate", hourly]]);
  byId("new-price-label").textContent = hourly ? "Đơn giá tối thiểu (USD/giờ)" : "Ngân sách (USD)";
});
newJob.elements.job_type.dispatchEvent(new Event("change"));
newJob.addEventListener("submit", async (event) => {
  event.preventDefault();
  const user = state.user;
  if (!inManagement(user, "client")) return;
  const fields = new FormData(newJob);
  const data = Object.fromEntries(fields);
  const levels = fields.getAll("required_level");
  const skills = fields.getAll("skill_id").map((skill, index) =>
    ({ skill_id: Number(skill), required_level: Number(levels[index]) }));
  if (new Set(skills.map(({ skill_id }) => skill_id)).size !== skills.length) {
    notice(manageFeedback, "Mỗi kỹ năng chỉ được chọn một lần.", "error");
    return;
  }
  const body = { client_id: user.user_id, title: data.title, description: data.description,
    category_id: Number(data.category_id), job_type: data.job_type, skills };
  if (data.job_type === "HOURLY") Object.assign(body, { rate_min: data.amount, rate_max: data.max_rate });
  else body.budget_amount = data.amount;
  const submit = newJob.querySelector("button[type=submit]");
  submit.disabled = true;
  try {
    await sendJson("/me/jobs", body);
    if (!inManagement(user, "client")) return;
    newJob.reset();
    while (jobSkills.children.length > 1) jobSkills.lastElementChild.remove();
    newJob.elements.job_type.dispatchEvent(new Event("change"));
    composer.hidden = true;
    jobFilter = "DRAFT";
    await loadOwnJobs(user);
    byId("own-jobs-title").scrollIntoView({ block: "nearest" });
    notice(manageFeedback, "Đã lưu bản nháp. Chọn Mở tin khi muốn nhận đề xuất.", "success");
  } catch (error) {
    if (inManagement(user, "client")) notice(manageFeedback, error.publicMessage || "Kiểm tra các trường của tin tuyển dụng.", "error");
  } finally {
    submit.disabled = false;
  }
});

async function loadFreelancer(user = state.user) {
  const proposals = await request("/me/proposals");
  if (!inManagement(user, "freelancer")) return;
  const rows = proposals.map((p) => {
    const actions = [];
    if (["SUBMITTED", "SHORTLISTED"].includes(p.status)) {
      actions.push(managedAction("Rút đề xuất", `/me/proposals/${p.proposal_id}/withdraw`, undefined, () => loadFreelancer(user)));
    }
    if (p.job_status === "OPEN" && ["SUBMITTED", "WITHDRAWN"].includes(p.status)) {
      const label = p.status === "WITHDRAWN" ? "Nộp lại" : "Sửa đề xuất";
      actions.push({ label, run: () => editOffer(p, label) });
    }
    return summaryRow(p.title, `#${p.proposal_id} · ${usd.format(p.offered_amount)}`, proposalStatus(p.status), actions);
  });
  byId("own-proposals").replaceChildren(...rows);
  if (!rows.length) byId("own-proposals").append(textElement("li", "contract-meta", "Bạn chưa gửi đề xuất."));
}

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
  submit.hidden = !save;
  dialogForm.onsubmit = async (event) => {
    if (!save) { event.preventDefault(); return; }
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

async function showApplicantProfile(userId) {
  const user = state.user;
  try {
    const profile = await request(`/freelancers/${userId}`);
    if (!inManagement(user, "client") || dialog.open) return;
    const rating = profile.review_count ? `${profile.avg_rating}/5 · ${profile.review_count} đánh giá` : "Chưa có đánh giá";
    const fields = [
      textElement("p", "applicant-headline", profile.headline),
      textElement("p", "contract-meta", `${usd.format(profile.default_hourly_rate)}/giờ · ${rating}`),
      textElement("p", "profile-description", profile.overview || "Chưa có phần giới thiệu."),
    ];
    if (profile.skills.length) {
      const skills = textElement("ul", "skills", "");
      skills.append(...profile.skills.map((skill) => textElement("li", "", skill.skill_name)));
      fields.push(skills);
    }
    openManageDialog(profile.full_name, fields);
  } catch (error) {
    if (inManagement(user, "client")) notice(manageFeedback, error.publicMessage || "Chưa đọc được hồ sơ.", "error");
  }
}

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
    jobFilter = "ALL";
    await loadOwnJobs();
    await loadApplicants({ ...job, status: "CLOSED" });
  });
}
