"use strict";

const profileFeedback = byId("profile-message");
const profileRoles = byId("profile-roles");
const skillForm = byId("edit-skills");
const experienceNames = { ENTRY: "Mới bắt đầu", INTERMEDIATE: "Có kinh nghiệm", EXPERT: "Chuyên gia" };
let profileRole = "freelancer";
let currentProfile = null;
let profileRequest = null;

function resetProfile() {
  profileRequest?.abort();
  currentProfile = null;
  for (const role of ["freelancer", "client"]) {
    byId(`${role}-profile`).reset();
    byId(`${role}-profile-editor`).hidden = true;
    byId(`${role}-profile-facts`).replaceChildren();
  }
  for (const id of ["profile-email", "profile-since", "profile-rating", "profile-handle", "profile-page-title", "profile-initials"]) {
    byId(id).textContent = "";
  }
  byId("own-skills").replaceChildren();
  skillForm.reset();
}

function inProfile(user) {
  return state.user === user && state.section === "profile";
}

async function loadProfile(role) {
  const user = state.user;
  if (!inProfile(user)) return;
  resetProfile();
  profileRole = role;
  const controller = new AbortController();
  profileRequest = controller;

  byId("profile-page-title").textContent = user.full_name;
  byId("profile-handle").textContent = `@${user.username}`;
  byId("profile-initials").textContent = initials(user.full_name);
  byId("profile-roles").parentElement.hidden = true;
  notice(profileFeedback, "Đang tải hồ sơ…");
  try {
    const data = await request("/me/profile", { signal: controller.signal });
    if (!inProfile(user) || profileRequest !== controller) return;
    currentProfile = data;
    byId("profile-email").textContent = data.account.email;
    byId("profile-since").textContent = formatDay(data.account.created_at);
    byId("profile-rating").textContent = data.account.review_count
      ? `${data.account.avg_rating}/5 · ${integers.format(data.account.review_count)} lượt` : "Chưa có đánh giá";
    byId("profile-roles").parentElement.hidden = false;
    displayProfileRole(profileRole);
    notice(profileFeedback);
  } catch (error) {
    if (inProfile(user) && profileRequest === controller && error.name !== "AbortError") {
      notice(profileFeedback, error.publicMessage || "Chưa đọc được hồ sơ. Bấm Hồ sơ của tôi để thử lại.", "error");
    }
  }
}

function profileFact(label, value, wide = false) {
  const row = textElement("div", wide ? "profile-fact-wide" : "", "");
  row.append(textElement("dt", "", label), textElement("dd", "", value || "Chưa bổ sung"));
  return row;
}

function displayProfileRole(role) {
  if (!currentProfile) return;
  profileRole = role;
  const profile = currentProfile[role];
  const editing = byId(`${role}-profile-editor`);
  for (const button of profileRoles.querySelectorAll("button")) {
    const otherRole = button.dataset.profileRole;
    button.setAttribute("aria-pressed", String(role === otherRole));
    byId(`${otherRole}-profile-panel`).hidden = role !== otherRole;
  }
  byId(`edit-${role}-profile`).hidden = !profile;
  byId(`edit-${role}-profile`).textContent = "Chỉnh sửa";
  editing.hidden = Boolean(profile);
  byId(`${role}-profile`).querySelector("button[type=submit]").textContent = profile ? "Lưu hồ sơ" : "Tạo hồ sơ";
  byId(`${role}-profile-title`).textContent = profile
    ? role === "client" ? "Hồ sơ khách hàng" : "Hồ sơ freelancer"
    : role === "client" ? "Thêm hồ sơ khách hàng" : "Thêm hồ sơ freelancer";

  const form = byId(`${role}-profile`);
  form.reset();
  const facts = byId(`${role}-profile-facts`);
  facts.replaceChildren();
  if (profile) {
    for (const field of form.elements) {
      if (field.name) field.value = profile[field.name] ?? "";
    }
    if (role === "freelancer") {
      facts.append(profileFact("Chức danh", profile.headline), profileFact("Đơn giá", `${usd.format(profile.default_hourly_rate)}/giờ`),
        profileFact("Kinh nghiệm", experienceNames[profile.experience_level]),
        profileFact("Khả năng nhận việc", profile.availability === "AVAILABLE" ? "Có thể nhận việc" : "Chưa nhận việc"),
        profileFact("Giới thiệu", profile.overview, true));
    } else {
      facts.append(profileFact("Công ty", profile.company_name), profileFact("Địa chỉ thanh toán · Riêng tư", profile.billing_address),
        profileFact("Giới thiệu công ty", profile.description, true));
    }
  }

  const freelancer = role === "freelancer" && profile;
  byId("profile-skills").hidden = !freelancer;
  if (freelancer) renderProfileSkills(freelancer.skills);
}

async function renderProfileSkills(rows) {
  const activeProfile = currentProfile;
  const list = byId("own-skills");
  list.replaceChildren(...rows.map((skill) => summaryRow(skill.skill_name, `Mức ${skill.proficiency_level}/5`, "",
    { label: "Bỏ kỹ năng", run: () => saveProfileSkills(rows.filter((row) => row.skill_id !== skill.skill_id)) })));
  if (!rows.length) list.append(textElement("li", "contract-meta", "Chưa có kỹ năng."));
  const user = state.user;
  try {
    const catalog = state.catalog || await request("/reference-data");
    if (!inProfile(user) || currentProfile !== activeProfile || profileRole !== "freelancer") return;
    const field = skillForm.elements.skill_id;
    const selection = field.value;
    catalogSelect(field, catalog.skills, "skill_id", "skill_name");
    field.value = selection;
  } catch (error) {
    if (inProfile(user) && currentProfile === activeProfile) notice(profileFeedback, "Chưa tải được danh mục kỹ năng.", "error");
  }
}

async function saveProfileSkills(rows) {
  const user = state.user;
  const region = byId("profile-skills");
  if (!inProfile(user) || region.inert) return;
  region.inert = true;
  try {
    await sendJson("/me/skills", { skills: rows.map(({ skill_id, proficiency_level }) => ({ skill_id, proficiency_level })) }, "PUT");
    if (inProfile(user)) {
      await loadProfile(profileRole);
      if (inProfile(user) && currentProfile) notice(profileFeedback, "Đã lưu kỹ năng.", "success");
    }
  } catch (error) {
    if (inProfile(user)) notice(profileFeedback, error.publicMessage || "Chưa thể cập nhật kỹ năng.", "error");
  } finally {
    region.inert = false;
  }
}

skillForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!currentProfile?.freelancer) return;
  const skill_id = Number(skillForm.elements.skill_id.value);
  const proficiency_level = Number(skillForm.elements.proficiency_level.value);
  saveProfileSkills([...currentProfile.freelancer.skills.filter((row) => row.skill_id !== skill_id),
    { skill_id, proficiency_level }]);
});

for (const button of profileRoles.querySelectorAll("button")) {
  button.addEventListener("click", () => {
    notice(profileFeedback);
    displayProfileRole(button.dataset.profileRole);
  });
}

for (const [role, optional] of [["client", "billing_address"], ["freelancer", "experience_level"]]) {
  const form = byId(`${role}-profile`);
  const editor = byId(`${role}-profile-editor`);
  const toggle = byId(`edit-${role}-profile`);
  toggle.addEventListener("click", () => {
    editor.hidden = !editor.hidden;
    toggle.textContent = editor.hidden ? "Chỉnh sửa" : "Đóng chỉnh sửa";
    if (!editor.hidden) form.querySelector("input").focus();
  });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const user = state.user;
    const add = !currentProfile?.[role];
    const button = event.submitter;
    const body = Object.fromEntries(new FormData(form));
    body[optional] = body[optional].trim() || null;
    button.disabled = true;
    try {
      await sendJson(`/me/profile/${role}`, body, add ? "POST" : "PUT");
      if (state.user !== user) return;
      if (add) {
        const identity = await request("/session");
        if (state.user !== user) return;
        refreshAccount(identity);
      }
      if (state.section === "profile") {
        await loadProfile(profileRole);
        if (currentProfile) notice(profileFeedback, add
          ? "Đã tạo hồ sơ. Bấm tên tài khoản ở góc trên để chuyển chế độ."
          : "Đã lưu hồ sơ.", "success");
      }
    } catch (error) {
      if (inProfile(user)) notice(profileFeedback, error.publicMessage || "Kiểm tra các trường rồi thử lại.", "error");
    } finally {
      button.disabled = false;
    }
  });
}

initialize();
