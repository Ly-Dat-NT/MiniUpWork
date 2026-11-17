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
  user: null, contract: null, contractRequest: null, savingContract: false,
};

async function request(path, options) {
  const response = await fetch(path, options);
  const body = await response.json().catch(() => null);
  if (!response.ok || body === null) {
    if (response.status === 401 && state.user) lockScreen();
    const error = new Error("API request failed");
    error.code = body?.detail?.code;
    error.status = response.status;
    error.publicMessage = body?.detail?.message;
    throw error;
  }
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
  element.textContent = text;
  return element;
}

function updateSubmit() {
  sendButton.disabled = state.saving || !state.current || !state.user?.is_freelancer;
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
  byId("show-proposal").hidden = job.status !== "OPEN" || !state.user?.is_freelancer;
  notice(byId("detail-message"), job.status !== "OPEN" ? "Công việc này đã ngừng nhận đề xuất." : "");
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
  if (!job || job.status !== "OPEN" || state.saving || !state.user?.is_freelancer) return;

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
  DISPUTED: "Đang đối soát", REFUNDED: "Đã hoàn ký quỹ", CANCELLED: "Đã hủy",
  ESCROW_RELEASE: "Giải ngân theo mốc", HOURLY_CHARGE: "Thanh toán theo giờ", REVERSAL: "Giao dịch bù",
  ELIGIBLE: "Đủ điều kiện", INELIGIBLE: "Không tính phí", OPEN: "Đang mở", CLOSED: "Đã đóng",
  PENDING: "Chờ xác nhận", SUCCEEDED: "Thành công", FAILED: "Thất bại",
  SHORTLISTED: "Qua vòng chọn lọc", ACCEPTED: "Đã chấp nhận", REJECTED: "Đã từ chối", WITHDRAWN: "Đã rút",
};

function formatDay(value) {
  return dateFormat.format(new Date(value.length === 10 ? `${value}T00:00:00Z` : value));
}

function lockScreen() {
  state.user = null;
  state.search?.abort();
  state.contractRequest?.abort();
  state.contract = null;
  state.references = false;
  if (drawer.open) drawer.close();
  list.replaceChildren();
  contractItems.replaceChildren();
  contractBody.replaceChildren();
  byId("account-name").textContent = "";
  for (const id of ["work-screen", "contract-screen", "manage-screen", "navigation", "account-bar"]) byId(id).hidden = true;
  byId("login-screen").hidden = false;
  loginForm.reset();
  byId("username").focus();
}

function showSection(section) {
  if (!state.user) return;
  for (const name of ["work", "contract", "manage"]) {
    byId(`${name}-screen`).hidden = section !== name;
    byId(`${name}-nav`).toggleAttribute("aria-current", section === name);
  }
  if (section === "contract") loadContracts();
  if (section === "manage") loadManagement();
}

function unlockScreen(user) {
  state.user = user;
  const role = user.is_client && user.is_freelancer ? "Khách hàng và freelancer" : user.is_client ? "Khách hàng" : "Freelancer";
  byId("account-name").textContent = `${user.full_name} · ${role}`;
  byId("login-screen").hidden = true;
  byId("account-bar").hidden = false;
  byId("navigation").hidden = false;
  searchForm.reset();
  state.params = new URLSearchParams();
  updateSearchPrices();
  state.offset = 0;
  showSection("work");
  loadReferences();
  search();
}

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
byId("work-nav").addEventListener("click", () => showSection("work"));
byId("contract-nav").addEventListener("click", () => showSection("contract"));
byId("manage-nav").addEventListener("click", () => showSection("manage"));

function emptyContract(message) {
  state.contractRequest?.abort();
  state.contract = null;
  contractBody.hidden = true;
  byId("contract-title").textContent = "Chi tiết hợp đồng";
  notice(contractFeedback, message);
}

async function loadContracts() {
  const user = state.user;
  const controller = new AbortController();
  state.contractRequest?.abort();
  state.contractRequest = controller;
  try {
    const rows = await request("/contracts", { signal: controller.signal });
    if (state.user !== user || state.contractRequest !== controller) return;
    contractItems.replaceChildren(...rows.map((row) => {
      const li = document.createElement("li");
      const button = document.createElement("button");
      button.className = "job-button";
      button.type = "button";
      button.dataset.contractId = row.contract_id;
      button.setAttribute("aria-pressed", "false");
      button.append(textElement("span", "job-meta-line", `#${row.contract_id} · ${row.contract_type === "HOURLY" ? "Theo giờ" : "Trọn gói"}`),
        textElement("span", "job-name", row.title), textElement("span", "job-category", statusNames[row.status] || row.status));
      button.addEventListener("click", () => selectContract(row.contract_id));
      li.append(button);
      return li;
    }));
    byId("contract-count").textContent = `${integers.format(rows.length)} hợp đồng`;
    notice(byId("contract-list-message"), rows.length ? "" : "Bạn chưa có hợp đồng.");
    if (rows.length) selectContract(state.contract?.contract_id || rows[0].contract_id);
    else emptyContract("Hợp đồng sẽ xuất hiện sau khi đề xuất được chấp nhận.");
  } catch (error) {
    if (error.name !== "AbortError" && state.user === user) notice(byId("contract-list-message"), "Không đọc được danh sách hợp đồng.", "error");
  }
}

async function selectContract(id) {
  emptyContract("Đang đọc chi tiết hợp đồng…");
  const controller = new AbortController();
  state.contractRequest = controller;
  for (const button of contractItems.querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.contractId === String(id)));
  }
  try {
    const data = await request(`/contracts/${id}`, { signal: controller.signal });
    if (state.contractRequest !== controller || controller.signal.aborted) return;
    state.contract = data;
    renderContract();
    notice(contractFeedback);
  } catch (error) {
    if (error.name !== "AbortError") notice(contractFeedback, "Không đọc được hợp đồng này.", "error");
  }
}

function summaryRow(title, body, status, actions = []) {
  const li = textElement("li", "contract-row", "");
  const description = document.createElement("div");
  description.append(textElement("strong", "", title), textElement("p", "", body), textElement("span", "job-category", status));
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

function contractGroup(title, rows, empty) {
  const content = textElement("ul", "contract-items", "");
  content.replaceChildren(...rows);
  contractBody.append(textElement("h3", "", title), rows.length ? content : textElement("p", "contract-meta", empty));
}

function contractForm(title, path, inputs, transform = (values) => values) {
  const details = document.createElement("details");
  const form = textElement("form", "work-form", "");
  details.append(textElement("summary", "", title), form);
  for (const [name, label, type, min, max, optional] of inputs) {
    const field = document.createElement("label");
    const input = document.createElement(type === "textarea" ? "textarea" : "input");
    input.name = name;
    if (type !== "textarea") input.type = type;
    if (min !== undefined) input.min = min;
    if (max !== undefined) input.max = max;
    input.required = !optional;
    field.append(label, input);
    form.append(field);
  }
  const submit = textElement("button", "button button-green", title);
  submit.type = "submit";
  form.append(submit);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    changeContract(path, transform(Object.fromEntries(new FormData(form))));
  });
  contractBody.append(details);
}

function renderContract() {
  const item = state.contract;
  const hourly = item.contract_type === "HOURLY";
  const active = item.status === "ACTIVE";
  const client = item.client_id === state.user.user_id;
  const rate = hourly ? `${usd.format(item.hourly_rate)} / giờ · Tối đa ${item.weekly_limit} giờ/tuần` : usd.format(item.agreed_amount);
  const actionLabels = { fund: "Xác nhận ký quỹ", submit: "Gửi bàn giao", approve: "Duyệt mốc",
    "prepare-release": "Giải ngân", "prepare-funding": "Ký quỹ", "cancel-funding": "Hủy ký quỹ đang chờ",
    "request-changes": "Yêu cầu sửa", cancel: "Hủy mốc", refund: "Hoàn ký quỹ" };
  const pending = item.payments.filter((row) => row.status === "PENDING");
  byId("contract-title").textContent = item.title;
  contractBody.replaceChildren(textElement("p", "contract-meta",
    `#${item.contract_id} · ${hourly ? "Theo giờ" : "Trọn gói"} · ${statusNames[item.status]} · ${rate}`),
    textElement("p", "contract-meta", `${item.company_name} · ${item.freelancer_name} · Từ ${formatDay(item.start_date)}`));

  if (client) {
    const stateActions = {
      DRAFT: [["ACTIVE", "Bắt đầu hợp đồng"], ["TERMINATED", "Kết thúc hợp đồng"]],
      ACTIVE: [["PAUSED", "Tạm dừng"], ["COMPLETED", "Đánh dấu hoàn thành"], ["TERMINATED", "Kết thúc hợp đồng"]],
      PAUSED: [["ACTIVE", "Tiếp tục"], ["TERMINATED", "Kết thúc hợp đồng"]],
    };
    const controls = textElement("div", "row-actions", "");
    for (const [status, label] of stateActions[item.status] || []) {
      const button = textElement("button", "button button-outline", label);
      button.type = "button";
      button.addEventListener("click", () => changeContract(`status/${status}`));
      controls.append(button);
    }
    if (controls.childElementCount) contractBody.append(controls);
  }

  if (hourly) {
    const invoiceActions = (row) => {
      const choices = client ? { ISSUED: [["approve", "Duyệt hóa đơn"], ["dispute", "Yêu cầu đối soát"]],
        DISPUTED: [["reopen", "Mở lại bản nháp"]], APPROVED: pending.some((p) => p.invoice_id === row.invoice_id)
          ? [] : [["prepare-payment", "Thanh toán hóa đơn"]] }
        : { DRAFT: [["issue", "Gửi hóa đơn"]] };
      return active ? (choices[row.status] || []).map(([action, label]) => ({ label, path: `invoices/${row.invoice_id}/${action}` })) : [];
    };
    contractGroup("Hóa đơn theo tuần", item.invoices.map((row) => summaryRow(
      `Tuần bắt đầu ${formatDay(row.period_start)}`, row.hours === null ? "Chưa ghi nhận giờ làm" : `${row.hours} giờ · ${usd.format(row.amount)}`,
      statusNames[row.status], invoiceActions(row))), "Chưa có hóa đơn.");
    contractGroup("Giờ làm", item.time_entries.map((row) => summaryRow(row.description,
      `${new Date(row.start_at).toLocaleString("vi-VN")} – ${new Date(row.end_at).toLocaleString("vi-VN")}`,
      row.invoice_id ? `Hóa đơn #${row.invoice_id}` : statusNames[row.eligibility_status],
      active && client && (!row.invoice_id || item.invoices.some((i) => i.invoice_id === row.invoice_id && i.status === "DRAFT")) ? { label: row.eligibility_status === "ELIGIBLE" ? "Loại khỏi hóa đơn" : "Cho phép tính phí",
        path: `time/${row.entry_id}/${row.eligibility_status === "ELIGIBLE" ? "INELIGIBLE" : "ELIGIBLE"}` } : null)), "Chưa ghi giờ.");
    if (active && !client) {
      contractForm("Ghi giờ làm", "time", [["start_at", "Bắt đầu", "datetime-local"], ["end_at", "Kết thúc", "datetime-local"],
        ["description", "Nội dung", "textarea"]], (values) => ({ ...values, start_at: new Date(values.start_at).toISOString(), end_at: new Date(values.end_at).toISOString() }));
      contractForm("Lập hóa đơn tuần", "invoices", [["period_start", "Thứ Hai đầu tuần UTC", "date"]]);
    }
  } else {
    contractGroup("Mốc bàn giao", item.milestones.map((row) => {
      const hasFunding = row.funding_history.some((e) => e.status === "PENDING");
      const choices = client ? {
        PLANNED: hasFunding ? ["fund", "cancel-funding"] : ["prepare-funding", "cancel"],
        REFUNDED: hasFunding ? ["fund", "cancel-funding"] : ["prepare-funding"], FUNDED: ["refund"],
        SUBMITTED: ["approve", "request-changes"],
        APPROVED: pending.some((p) => p.milestone_id === row.milestone_id) ? [] : ["prepare-release"],
      } : { FUNDED: ["submit"] };
      const actions = active ? (choices[row.status] || []) : [];
      return summaryRow(`${row.sequence_no}. ${row.title}`, `${usd.format(row.amount)} · Hạn ${formatDay(row.due_date)}`, statusNames[row.status],
        actions.map((action) => ({ label: actionLabels[action], path: `milestones/${row.milestone_id}/${action}` })));
    }), "Chưa có mốc bàn giao.");
    const funding = item.milestones.flatMap((m) => m.funding_history.map((e) => summaryRow(
      `Ký quỹ #${e.funding_id} · mốc ${m.sequence_no}`, `${usd.format(m.amount)}${e.settled_at ? ` · ${formatDay(e.settled_at)}` : ""}`,
      statusNames[e.status] || e.status)));
    if (funding.length) contractGroup("Lịch sử ký quỹ", funding, "");
  }
  const paymentRows = item.payments.map((row) => {
    const path = `payments/${row.payment_id}`;
    const actions = [];
    if (row.status === "PENDING" && row.payer_id === state.user.user_id) {
      if (active || row.transaction_type === "REVERSAL") {
        actions.push({ label: "Xác nhận thanh toán", path: `${path}/result/SUCCEEDED` });
      }
      actions.push({ label: "Ghi nhận thất bại", path: `${path}/result/FAILED` });
    }
    if (row.status === "SUCCEEDED" && row.payee_id === state.user.user_id && !row.reversed && row.transaction_type !== "REVERSAL") {
      actions.push({ label: "Ghi giao dịch bù", path: `${path}/reverse` });
    }
    const id = row.original_payment_id ? `Bù cho #${row.original_payment_id}` : `#${row.payment_id}`;
    return summaryRow(statusNames[row.transaction_type], `${id} · ${usd.format(row.amount)} · ${formatDay(row.created_at)}`,
      statusNames[row.status], actions);
  });
  contractGroup("Lịch sử thanh toán", paymentRows, "Chưa có giao dịch được ghi nhận.");
  if (item.reviews.length) contractGroup("Đánh giá", item.reviews.map((row) => summaryRow(row.reviewer, row.comment ?? "", `${row.rating}/5`)), "");
  if (item.status === "COMPLETED" && !item.reviews.some((row) => row.reviewer_id === state.user.user_id)) {
    contractForm("Gửi đánh giá", "reviews", [["rating", "Điểm", "number", 1, 5], ["comment", "Nhận xét (tùy chọn)", "textarea", undefined, undefined, true]],
      (values) => ({ rating: Number(values.rating), comment: values.comment.trim() || null }));
  }
  contractBody.hidden = false;
}

async function changeContract(path, body) {
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
      await selectContract(item.contract_id);
      if (state.contract?.contract_id === item.contract_id) {
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

initialize();
