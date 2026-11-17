"use strict";

const byId = (id) => document.getElementById(id);
const searchForm = byId("search-form");
const proposalForm = byId("proposal-form");
const sendButton = byId("send");
const list = byId("jobs");
const drawer = byId("job-drawer");
const priceFields = [searchForm.elements.price_min, searchForm.elements.price_max];
const filterFields = [byId("category"), byId("skill"), byId("job-type"), ...priceFields];
const pageSize = 10;
const usd = new Intl.NumberFormat("vi-VN", { style: "currency", currency: "USD", currencyDisplay: "code" });
const integers = new Intl.NumberFormat("vi-VN");
const dateFormat = new Intl.DateTimeFormat("vi-VN", {
  day: "numeric", month: "short", year: "numeric", timeZone: "Asia/Ho_Chi_Minh",
});

const state = {
  params: new URLSearchParams(), offset: 0, total: 0, current: null,
  search: null, detail: null, saving: false, references: false,
  user: null, mode: null, section: null, contract: null, contractRequest: null, savingContract: false,
  contractRows: [], contractType: "FIXED_PRICE", selectedContractId: null,
};

const apiOrigin = document.querySelector('meta[name="miniupwork-api"]').content;
const tokenKey = `miniupwork:session:${location.pathname}:${apiOrigin}`;
let accessToken = null;
if (apiOrigin) {
  try { accessToken = sessionStorage.getItem(tokenKey); } catch { /* browser storage can be disabled */ }
}

function saveAccessToken(token) {
  accessToken = token;
  try {
    if (token) sessionStorage.setItem(tokenKey, token);
    else sessionStorage.removeItem(tokenKey);
  } catch { /* the session stays in memory */ }
}

async function request(path, options) {
  if (apiOrigin) {
    const headers = new Headers(options?.headers);
    if (accessToken) headers.set("Authorization", `Bearer ${accessToken}`);
    options = { ...options, headers, credentials: "omit", redirect: "error" };
  }
  const response = await fetch(apiOrigin + path, options);
  const body = await response.json().catch(() => null);
  if (!response.ok || body === null) {
    if (apiOrigin && response.status === 401) saveAccessToken(null);
    if (response.status === 401 && state.user) lockScreen();
    const error = new Error("API request failed");
    error.code = body?.detail?.code;
    error.status = response.status;
    error.publicMessage = body?.detail?.message;
    throw error;
  }
  if (apiOrigin && path === "/login") saveAccessToken(body.access_token);
  if (apiOrigin && path === "/logout") saveAccessToken(null);
  return body;
}

function notice(element, message = "", tone = "info") {
  element.textContent = message;
  element.hidden = !message;
  element.dataset.state = tone;
}

function connection(ready) {
  const status = byId("connection");
  status.dataset.state = ready ? "ready" : "error";
  status.textContent = ready ? "Đã kết nối CSDL" : "CSDL chưa sẵn sàng";
}

function fillOptions(select, rows, value, label) {
  const options = rows.map((row) => new Option(label(row), String(row[value])));
  select.replaceChildren(select.options[0], ...options);
}

function categoryChoices(categories) {
  const names = new Map(categories.map((row) => [row.category_id, row.category_name]));
  return categories.map((row) => {
    const parent = names.get(row.parent_category_id);
    return { ...row, category_name: parent ? `${parent} / ${row.category_name}` : row.category_name };
  });
}

async function loadReferences() {
  try {
    const refs = await request("/reference-data");
    fillOptions(byId("category"), categoryChoices(refs.categories), "category_id", (item) => item.category_name);
    fillOptions(byId("skill"), refs.skills, "skill_id", (item) => item.skill_name);
    state.catalog = refs;
    state.references = true;
    connection(true);
  } catch {
    state.references = false;
    connection(false);
  }
  updateSubmit();
}

function formatPrice(job) {
  const pricing = job.pricing;
  return job.job_type === "HOURLY"
    ? `${usd.format(pricing.rate_min)} – ${usd.format(pricing.rate_max)} / giờ`
    : usd.format(pricing.budget_amount);
}

function typeName(job) {
  return job.job_type === "HOURLY" ? "Theo giờ" : "Trọn gói";
}

function textElement(tag, className, text) {
  const element = document.createElement(tag);
  element.className = className;
  element.textContent = typeof text === "string" ? text.normalize("NFC") : text;
  return element;
}

function updateSubmit() {
  sendButton.disabled = state.saving || !canSubmit(state.current);
  sendButton.textContent = state.saving ? "Đang gửi…" : "Gửi đề xuất";
}

function resetDetail(message) {
  state.detail?.abort();
  state.current = null;
  proposalForm.reset();
  proposalForm.hidden = true;
  notice(byId("proposal-message"));
  byId("job-content").hidden = true;
  byId("job-meta").hidden = true;
  byId("detail-title").textContent = "Chi tiết công việc";
  notice(byId("detail-message"), message);
  updateSubmit();
}

function displayJob(job) {
  const hourly = job.job_type === "HOURLY";
  byId("job-meta").textContent = `#${job.job_id} · ${job.category_name} · ${typeName(job)}`;
  byId("job-meta").hidden = false;
  byId("detail-title").textContent = job.title;
  byId("client").textContent = job.company_name;
  byId("price-label").textContent = hourly ? "Đơn giá" : "Ngân sách";
  byId("price").textContent = formatPrice(job);
  byId("description").textContent = job.description;
  byId("job-skills").replaceChildren(...job.skills.map((skill) =>
    textElement("li", "", `${skill.skill_name} · Mức ${skill.required_level}`)));
  byId("offer-label").textContent = hourly ? "Đơn giá đề xuất (USD/giờ)" : "Tổng giá đề xuất (USD)";
  byId("show-proposal").hidden = !canSubmit(job);
  const message = job.status !== "OPEN" ? "Công việc này đã ngừng nhận đề xuất."
    : job.client_id === state.user?.user_id ? "Bạn đã đăng tin này." : "";
  notice(byId("detail-message"), message);
  byId("job-content").hidden = false;
  updateSubmit();
}

async function selectJob(id) {
  resetDetail("Đang đọc chi tiết công việc…");
  const controller = new AbortController();
  state.detail = controller;
  drawer.showModal();
  drawer.scrollTop = 0;
  try {
    const job = await request(`/jobs/${id}`, { signal: controller.signal });
    if (state.detail !== controller || controller.signal.aborted) return;
    state.current = job;
    displayJob(job);
  } catch (error) {
    if (error.name === "AbortError" || state.detail !== controller) return;
    notice(byId("detail-message"), "Không đọc được chi tiết. Hãy chọn lại công việc.", "error");
    if (error.status === 503) connection(false);
  }
}

function displayActiveFilters() {
  const chips = byId("active-filters");
  chips.replaceChildren();
  for (const field of filterFields) {
    const value = state.params.get(field.name);
    if (!value) continue;
    const label = field.options ? Array.from(field.options).find((option) => option.value === value)?.label || value
      : `${field.name === "price_min" ? "Từ" : "Đến"} ${usd.format(value)}`;
    const item = document.createElement("li");
    const remove = textElement("button", "active-filter", label);
    remove.type = "button";
    remove.setAttribute("aria-label", `Bỏ bộ lọc ${label}`);
    const mark = textElement("span", "", "×");
    mark.setAttribute("aria-hidden", "true");
    remove.append(mark);
    remove.addEventListener("click", () => {
      field.value = "";
      state.params.delete(field.name);
      updateSearchPrices();
      state.offset = 0;
      searchForm.elements.q.focus();
      search();
    });
    item.append(remove);
    chips.append(item);
  }
  chips.hidden = chips.childElementCount === 0;
  byId("clear-filters").hidden = chips.hidden;
}

function displayResults(result) {
  state.total = result.total;
  list.replaceChildren(...result.items.map((job) => {
    const item = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.className = "job-button";
    button.setAttribute("aria-haspopup", "dialog");
    button.setAttribute("aria-controls", "job-drawer");
    const arrow = textElement("span", "job-arrow", "↗");
    arrow.setAttribute("aria-hidden", "true");
    button.append(
      textElement("span", "job-meta-line", `${job.company_name} · ${typeName(job)} · ${dateFormat.format(new Date(job.posted_at))}`),
      textElement("span", "job-name", job.title),
      textElement("span", "job-price", formatPrice(job)),
      textElement("span", "job-excerpt", job.description),
      textElement("span", "job-category", job.category_name),
      arrow,
    );
    button.addEventListener("click", () => selectJob(job.job_id));
    item.append(button);
    return item;
  }));
  byId("result-count").textContent = `${integers.format(result.total)} công việc`;
  byId("feed-sort").hidden = result.total === 0;
  byId("pagination").hidden = result.total <= pageSize;
  byId("previous").disabled = state.offset === 0;
  byId("next").disabled = state.offset + pageSize >= result.total;
  byId("page-label").textContent = `Trang ${Math.floor(state.offset / pageSize) + 1} / ${Math.ceil(result.total / pageSize)}`;

  if (!result.items.length) {
    notice(byId("search-message"), "Không có công việc khớp bộ lọc.");
    return;
  }
  notice(byId("search-message"));
}

async function search() {
  state.search?.abort();
  const controller = new AbortController();
  state.search = controller;
  const keyword = state.params.get("q");
  byId("results-title").textContent = keyword ? `Kết quả cho “${keyword}”` : "Công việc đang mở";
  displayActiveFilters();
  list.setAttribute("aria-busy", "true");
  list.inert = true;
  byId("previous").disabled = true;
  byId("next").disabled = true;
  notice(byId("search-message"), "Đang tìm công việc…");

  const params = new URLSearchParams(state.params);
  params.set("limit", pageSize);
  params.set("offset", state.offset);
  try {
    const result = await request(`/jobs?${params}`, { signal: controller.signal });
    if (state.search !== controller || controller.signal.aborted) return;
    connection(true);
    if (result.total && !result.items.length && state.offset > 0) {
      state.offset = Math.floor((result.total - 1) / pageSize) * pageSize;
      search();
      return;
    }
    displayResults(result);
  } catch (error) {
    if (error.name === "AbortError" || state.search !== controller) return;
    list.replaceChildren();
    byId("result-count").textContent = "";
    byId("feed-sort").hidden = true;
    byId("pagination").hidden = true;
    notice(byId("search-message"), "Không tải được công việc. Kiểm tra kết nối rồi bấm Tìm việc để thử lại.", "error");
    if (error.status === 503 || error instanceof TypeError) connection(false);
  } finally {
    if (state.search === controller) {
      list.removeAttribute("aria-busy");
      list.inert = false;
    }
  }
}

function setFiltersExpanded(expanded) {
  const toggle = byId("toggle-filters");
  const options = byId("filter-options");
  if (!expanded && toggle.getClientRects().length && options.contains(document.activeElement)) toggle.focus();
  toggle.setAttribute("aria-expanded", String(expanded));
  options.dataset.expanded = String(expanded);
}

function updateSearchPrices() {
  const hasType = Boolean(byId("job-type").value);
  byId("price-range").hidden = !hasType;
  for (const field of priceFields) {
    field.disabled = !hasType;
    if (!hasType) {
      field.value = "";
      state.params.delete(field.name);
    }
  }
}

searchForm.addEventListener("submit", (event) => {
  event.preventDefault();
  state.params = new URLSearchParams();
  for (const [name, value] of new FormData(searchForm)) {
    if (value.trim()) state.params.set(name, value.trim());
  }
  state.offset = 0;
  setFiltersExpanded(false);
  if (!state.references) loadReferences();
  search();
});
byId("toggle-filters").addEventListener("click", (event) => {
  setFiltersExpanded(event.currentTarget.getAttribute("aria-expanded") !== "true");
});
byId("clear-filters").addEventListener("click", () => {
  for (const field of filterFields) {
    field.value = "";
    state.params.delete(field.name);
  }
  updateSearchPrices();
  state.offset = 0;
  searchForm.elements.q.focus();
  search();
});
byId("job-type").addEventListener("change", updateSearchPrices);
byId("previous").addEventListener("click", () => {
  state.offset = Math.max(0, state.offset - pageSize);
  search();
});
byId("next").addEventListener("click", () => {
  if (state.offset + pageSize < state.total) {
    state.offset += pageSize;
    search();
  }
});

byId("close-job").addEventListener("click", () => drawer.close());
drawer.addEventListener("click", (event) => {
  if (event.target === drawer) drawer.close();
});
drawer.addEventListener("close", () => {
  if (!drawer.open) resetDetail();
});
byId("show-proposal").addEventListener("click", (event) => {
  proposalForm.hidden = false;
  event.currentTarget.hidden = true;
  byId("offer").focus({ preventScroll: true });
  proposalForm.scrollIntoView({ block: "start" });
});

const rejectionMessages = {
  duplicate_record: "Freelancer này đã có đề xuất cho công việc. CSDL từ chối tạo bản ghi trùng.",
  self_bid: "Không thể ứng tuyển công việc do chính tài khoản này đăng.",
  state_conflict: "Công việc hiện không nhận đề xuất. Hãy tìm một công việc đang mở.",
  inactive_profile: "Tài khoản freelancer này đã ngừng hoạt động.",
  not_found: "Không tìm thấy công việc hoặc hồ sơ freelancer.",
  concurrent_change: "Dữ liệu vừa thay đổi. Hãy thử gửi lại.",
};

proposalForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const job = state.current;
  if (!canSubmit(job) || state.saving) return;

  const body = {
    cover_letter: byId("letter").value.trim(),
    offered_amount: byId("offer").value,
  };
  const feedback = byId("proposal-message");
  if (!body.cover_letter) {
    notice(feedback, "Nhập thư giới thiệu trước khi gửi.", "error");
    byId("letter").focus();
    return;
  }

  state.saving = true;
  updateSubmit();
  notice(feedback, "Đang ghi đề xuất vào CSDL…");
  try {
    const result = await request(`/jobs/${job.job_id}/proposals`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (state.current === job) {
      notice(feedback, `Đã lưu đề xuất #${result.proposal_id} · ${result.status}.`, "success");
    }
  } catch (error) {
    if (error.status === 503 || error instanceof TypeError) connection(false);
    if (state.current !== job) return;
    const message = rejectionMessages[error.code] || (error.status === 422
      ? "Kiểm tra tài khoản, mức đề xuất và thư giới thiệu rồi thử lại."
      : "Chưa xác nhận được đề xuất đã lưu. Hãy kiểm tra kết nối trước khi gửi lại.");
    notice(feedback, message, "error");
  } finally {
    state.saving = false;
    updateSubmit();
  }
});

const loginForm = byId("login-form");
const contractItems = byId("contract-items");
const contractBody = byId("contract-content");
const contractFeedback = byId("contract-message");
const statusNames = {
  DRAFT: "Bản nháp", ACTIVE: "Đang thực hiện", PAUSED: "Tạm dừng", COMPLETED: "Hoàn thành",
  TERMINATED: "Đã kết thúc", PLANNED: "Chờ ký quỹ", FUNDED: "Đã ký quỹ", SUBMITTED: "Đã bàn giao",
  APPROVED: "Đã duyệt", RELEASED: "Đã giải ngân", PAID: "Đã thanh toán", ISSUED: "Đã lập hóa đơn",
  NO_CHARGE: "Đã duyệt · Không thu tiền", VOID: "Hóa đơn đã hủy",
  DISPUTED: "Đang đối soát", REFUNDED: "Đã hoàn ký quỹ", CANCELLED: "Đã hủy",
  ESCROW_RELEASE: "Giải ngân theo mốc", HOURLY_CHARGE: "Thu tiền theo giờ", REVERSAL: "Giao dịch bù",
  ESCROW_DEPOSIT: "Nạp tiền vào ký quỹ", ESCROW_REFUND: "Hoàn ký quỹ cho khách", HOURLY_PAYOUT: "Chi trả cho freelancer",
  ELIGIBLE: "Đủ điều kiện", INELIGIBLE: "Không tính phí", OPEN: "Đang mở", CLOSED: "Đã đóng",
  PENDING: "Chờ xác nhận", SUCCEEDED: "Thành công", FAILED: "Thất bại",
  SHORTLISTED: "Qua vòng chọn lọc", ACCEPTED: "Đã chấp nhận", REJECTED: "Đã từ chối", WITHDRAWN: "Đã rút",
};

function formatDay(value) {
  return dateFormat.format(new Date(value.length === 10 ? `${value}T00:00:00Z` : value));
}

const workspaces = { freelancer: "Freelancer", client: "Khách hàng" };
const accountMenu = byId("account-menu");

function initials(name) {
  return name.trim().split(/\s+/).slice(-2).map((part) => Array.from(part)[0]).join("").toLocaleUpperCase("vi");
}

function canSubmit(job) {
  return job?.status === "OPEN" && state.mode === "freelancer" && job.client_id !== state.user?.user_id;
}

function refreshAccount(user) {
  state.user = user;
  byId("account-name").textContent = user.full_name;
  byId("account-initials").textContent = initials(user.full_name);
  byId("account-role").textContent = workspaces[state.mode];
  for (const button of accountMenu.querySelectorAll("[data-workspace]")) {
    const role = button.dataset.workspace;
    button.textContent = user[`is_${role}`] ? workspaces[role]
      : role === "client" ? "Thêm hồ sơ khách hàng" : "Thêm hồ sơ freelancer";
    button.setAttribute("aria-pressed", String(state.mode === role));
  }
}

function lockScreen() {
  state.user = null;
  state.mode = null;
  state.section = null;
  state.search?.abort();
  state.contractRequest?.abort();
  state.contract = null;
  state.contractRows = [];
  state.contractType = "FIXED_PRICE";
  state.selectedContractId = null;
  state.references = false;
  state.catalog = null;
  if (drawer.open) drawer.close();
  accountMenu.open = false;
  resetManagement();
  resetProfile();
  list.replaceChildren();
  contractItems.replaceChildren();
  contractBody.replaceChildren();
  byId("client-wallet").replaceChildren();
  byId("client-wallet").hidden = true;
  byId("account-name").textContent = "";
  for (const id of ["work-screen", "contract-screen", "manage-screen", "profile-screen", "navigation", "account-bar"]) byId(id).hidden = true;
  byId("login-screen").hidden = false;
  loginForm.reset();
  byId("username").focus();
}

function showSection(section, { profileRole = state.mode } = {}) {
  if (!state.user) return;
  state.section = section;
  for (const name of ["work", "contract", "manage", "profile"]) {
    byId(`${name}-screen`).hidden = section !== name;
  }
  const activeNav = section === "manage" ? "work" : section;
  for (const name of ["work", "contract", "profile"]) {
    const button = byId(`${name}-nav`);
    if (name === activeNav) button.setAttribute("aria-current", "page");
    else button.removeAttribute("aria-current");
  }
  if (section === "contract") loadContracts();
  if (section === "manage") loadManagement();
  if (section === "profile") loadProfile(profileRole);
}

function workspaceKey(user) {
  return `miniupwork:workspace:${user.user_id}:${user.username}`;
}

function switchWorkspace(role) {
  if (!state.user?.[`is_${role}`]) return;
  accountMenu.open = false;
  state.mode = role;
  state.search?.abort();
  state.contractRequest?.abort();
  state.contract = null;
  state.contractRows = [];
  state.selectedContractId = null;
  if (drawer.open) drawer.close();
  if (!byId("profile-screen").hidden) resetProfile();
  refreshAccount(state.user);
  try { localStorage.setItem(workspaceKey(state.user), role); } catch { /* browser storage can be disabled */ }
  byId("work-nav").textContent = role === "client" ? "Tuyển dụng" : "Tìm việc";
  showSection(role === "client" ? "manage" : "work");
  if (role === "freelancer") {
    if (!state.references) loadReferences();
    search();
  }
}

function unlockScreen(user) {
  state.user = user;
  let saved = null;
  try { saved = localStorage.getItem(workspaceKey(user)); } catch { /* browser storage can be disabled */ }
  const role = Object.hasOwn(workspaces, saved) && user[`is_${saved}`] ? saved
    : user.is_freelancer ? "freelancer" : "client";
  byId("login-screen").hidden = true;
  byId("account-bar").hidden = false;
  byId("navigation").hidden = false;
  searchForm.reset();
  state.params = new URLSearchParams();
  updateSearchPrices();
  state.offset = 0;
  switchWorkspace(role);
}

for (const button of accountMenu.querySelectorAll("[data-workspace]")) {
  button.addEventListener("click", () => {
    const role = button.dataset.workspace;
    accountMenu.open = false;
    if (state.user?.[`is_${role}`]) switchWorkspace(role);
    else showSection("profile", { profileRole: role });
  });
}
document.addEventListener("click", (event) => {
  if (accountMenu.open && !accountMenu.contains(event.target)) accountMenu.open = false;
});
accountMenu.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    accountMenu.open = false;
    accountMenu.querySelector("summary").focus();
  }
});

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const submit = loginForm.querySelector("button[type=submit]");
  const fields = new FormData(loginForm);
  submit.disabled = true;
  notice(byId("login-message"), "Đang đăng nhập…");
  try {
    await request("/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({
      username: fields.get("username").trim(), password: fields.get("password"),
    }) });
    const user = await request("/session");
    loginForm.reset();
    notice(byId("login-message"));
    unlockScreen(user);
  } catch (error) {
    notice(byId("login-message"), error.status === 401 ? "Tên đăng nhập hoặc mật khẩu không đúng."
      : error.status === 422 ? "Kiểm tra tên đăng nhập và mật khẩu."
      : "Chưa thể kết nối CSDL. Kiểm tra lại ứng dụng rồi thử tiếp.", "error");
  } finally {
    submit.disabled = false;
  }
});

byId("logout").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  button.disabled = true;
  try {
    await request("/logout", { method: "POST" });
    lockScreen();
  } catch {
    const indicator = byId("connection");
    indicator.dataset.state = "error";
    indicator.textContent = "Chưa thể đăng xuất. Hãy thử lại.";
  } finally {
    button.disabled = false;
  }
});
byId("work-nav").addEventListener("click", () => showSection(state.mode === "client" ? "manage" : "work"));
byId("contract-nav").addEventListener("click", () => showSection("contract"));
byId("proposals-shortcut").addEventListener("click", () => showSection("manage"));
byId("profile-nav").addEventListener("click", () => showSection("profile"));

function emptyContract(message) {
  state.contractRequest?.abort();
  state.contract = null;
  contractBody.hidden = true;
  notice(contractFeedback, message);
}

async function loadContracts() {
  const user = state.user;
  const mode = state.mode;
  loadClientWallet();
  const switches = byId("contract-types").querySelectorAll("button");
  switches.forEach((button) => { button.disabled = true; });
  emptyContract("");
  contractItems.replaceChildren();
  byId("contract-count").textContent = "";
  notice(byId("contract-list-message"), "Đang đọc danh sách hợp đồng…");
  const controller = new AbortController();
  state.contractRequest = controller;
  try {
    const rows = await request(`/contracts?role=${mode}`, { signal: controller.signal });
    if (state.user !== user || state.contractRequest !== controller) return;
    state.contractRows = rows;
    switches.forEach((button) => { button.disabled = false; });
    const selected = rows.find((row) => row.contract_id === state.selectedContractId);
    if (selected) state.contractType = selected.contract_type;
    else if (rows.length && !rows.some((row) => row.contract_type === state.contractType)) {
      state.contractType = rows[0].contract_type;
    }
    showContractType(state.contractType, state.selectedContractId);
  } catch (error) {
    if (error.name !== "AbortError" && state.user === user) notice(byId("contract-list-message"), "Không đọc được danh sách hợp đồng.", "error");
  }
}

function showContractType(type, preferredId = null) {
  state.contractType = type;
  for (const button of byId("contract-types").querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.contractType === type));
  }
  const rows = state.contractRows.filter((row) => row.contract_type === type);
  byId("contract-count").textContent = `${integers.format(rows.length)} hợp đồng ${type === "HOURLY" ? "theo giờ" : "trọn gói"}`;
  contractItems.replaceChildren(...rows.map((row) => {
    const li = document.createElement("li");
    const button = textElement("button", "contract-option", "");
    button.type = "button";
    button.dataset.contractId = row.contract_id;
    button.setAttribute("aria-pressed", "false");
    button.append(textElement("span", "contract-option-id", `#${row.contract_id}`),
      textElement("strong", "", row.title),
      textElement("span", "contract-option-status", statusNames[row.status] || row.status));
    button.addEventListener("click", () => selectContract(row.contract_id));
    li.append(button);
    return li;
  }));
  notice(byId("contract-list-message"), rows.length ? "" : "Bạn chưa có hợp đồng thuộc loại này.");
  if (rows.length) selectContract(rows.find((row) => row.contract_id === preferredId)?.contract_id ?? rows[0].contract_id);
  else {
    state.selectedContractId = null;
    emptyContract("");
  }
}

for (const button of byId("contract-types").querySelectorAll("button")) {
  button.addEventListener("click", () => {
    if (button.dataset.contractType !== state.contractType) showContractType(button.dataset.contractType);
  });
}

async function selectContract(id) {
  if (state.selectedContractId !== id) resetContractPanel();
  state.selectedContractId = id;
  emptyContract("Đang đọc chi tiết hợp đồng…");
  const controller = new AbortController();
  state.contractRequest = controller;
  for (const button of contractItems.querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.contractId === String(id)));
  }
  try {
    const data = await request(`/contracts/${id}`, { signal: controller.signal });
    if (state.contractRequest !== controller || controller.signal.aborted) return false;
    state.contract = data;
    const choice = state.contractRows.find((row) => row.contract_id === id);
    if (choice) choice.status = data.status;
    const label = contractItems.querySelector('[aria-pressed="true"] .contract-option-status');
    if (label) label.textContent = statusNames[data.status] || data.status;
    renderContract();
    notice(contractFeedback);
    return true;
  } catch (error) {
    if (error.name !== "AbortError" && state.contractRequest === controller) {
      notice(contractFeedback, "Không đọc được hợp đồng này.", "error");
    }
    return false;
  }
}

function summaryRow(title, body, status, actions = []) {
  const li = textElement("li", "contract-row", "");
  const description = document.createElement("div");
  description.append(textElement("strong", "", title), textElement("p", "", body));
  if (status) description.append(textElement("span", "job-category", status));
  li.append(description);
  if (!Array.isArray(actions)) actions = actions ? [actions] : [];
  if (actions.length) {
    const controls = textElement("div", "row-actions", "");
    for (const action of actions) {
    const button = textElement("button", "button button-outline", action.label);
    button.type = "button";
    button.addEventListener("click", action.run || (() => changeContract(action.path)));
    controls.append(button);
    }
    li.append(controls);
  }
  return li;
}

async function changeContract(path, body, after) {
  const item = state.contract;
  if (!item || state.savingContract) return;
  state.savingContract = true;
  contractBody.querySelectorAll("button").forEach((button) => { button.disabled = true; });
  notice(contractFeedback, "Đang ghi thay đổi…");
  try {
    const options = { method: "POST" };
    if (body) Object.assign(options, { headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    const result = await request(`/contracts/${item.contract_id}/${path}`, options);
    if (state.contract === item) {
      if (state.mode === "client") loadClientWallet();
      after?.(result);
      if (await selectContract(item.contract_id)) {
        const paymentStatus = statusNames[result.status];
        const message = result.payment_id
          ? `Đã ghi giao dịch #${result.payment_id}${paymentStatus ? ` · ${paymentStatus}` : ""}.`
          : statusNames[result.status] ? `${statusNames[result.status]}.` : "Đã cập nhật hợp đồng.";
        notice(contractFeedback, message, "success");
      }
    }
  } catch (error) {
    if (state.contract === item) notice(contractFeedback, error.publicMessage || "Chưa xác nhận được thay đổi.", "error");
  } finally {
    state.savingContract = false;
    contractBody.querySelectorAll("button").forEach((button) => { button.disabled = false; });
  }
}

async function initialize() {
  request("/health").then(() => connection(true)).catch(() => connection(false));
  try {
    unlockScreen(await request("/session"));
  } catch {
    lockScreen();
  }
}

