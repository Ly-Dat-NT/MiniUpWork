"use strict";

const contractPanel = { tab: "progress", preview: "unbilled", week: null, invoice: null };
const contractTabs = [
  ["progress", "Tiến độ và thanh toán"],
  ["history", "Hóa đơn và giao dịch"],
  ["reviews", "Đánh giá hai chiều"],
];
const milestoneSteps = ["Nạp ký quỹ", "Nộp sản phẩm", "Nghiệm thu và giải ngân", "Gửi đánh giá"];
const hoursFormat = new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 2 });
const walletLabels = {
  BANK_TOP_UP: "Nạp từ ngân hàng",
  ESCROW_DEPOSIT: "Chuyển tiền vào ký quỹ",
  ESCROW_REFUND: "Hoàn ký quỹ",
  HOURLY_CHARGE: "Thanh toán hóa đơn theo giờ",
  REVERSAL: "Hoàn tiền giao dịch",
  CANCELLATION_PENALTY: "Phí hủy hợp đồng đã khấu trừ",
  CANCELLATION_FEE_PAYMENT: "Freelancer thanh toán phí hủy",
};
let walletRequest;

async function loadClientWallet() {
  const panel = byId("client-wallet");
  const owner = state.user;
  walletRequest?.abort();
  panel.hidden = state.mode !== "client";
  if (panel.hidden) {
    panel.replaceChildren();
    return;
  }
  if (!panel.firstElementChild) {
    const header = textElement("div", "wallet-header", "");
    const heading = textElement("h2", "workflow-heading", "Ví khách hàng");
    heading.id = "wallet-title";
    const balance = textElement("strong", "wallet-balance", "—");
    balance.id = "wallet-balance";
    balance.setAttribute("aria-live", "polite");
    header.append(heading, balance);
    const deposit = textElement("details", "contract-editor wallet-editor", "");
    deposit.append(textElement("summary", "", "Nạp tiền từ ngân hàng"));
    const form = textElement("form", "work-form wallet-form", "");
    const amount = contractField("amount", "Số tiền nạp (USD)", "number", { min: 0.01, max: 9999999999.99, step: 0.01 });
    const submit = textElement("button", "button button-green", "Xác nhận nạp");
    submit.type = "submit";
    form.append(textElement("p", "contract-meta", "Chuyển khoản mô phỏng. Số dư dùng cho ký quỹ và thanh toán hóa đơn theo giờ."), amount, submit);
    deposit.append(form);
    const feedback = textElement("p", "notice", "");
    feedback.setAttribute("role", "status");
    feedback.hidden = true;
    const history = textElement("details", "contract-editor wallet-history", "");
    history.append(textElement("summary", "", "Giao dịch gần đây"));
    const entries = textElement("div", "", "");
    entries.id = "wallet-entries";
    history.append(entries);
    panel.append(header, deposit, feedback, history);

    let attempt = null;
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (submit.disabled || state.user !== owner || state.mode !== "client") return;
      const value = new FormData(form).get("amount");
      if (attempt?.amount !== value) attempt = { amount: value, reference: crypto.randomUUID() };
      submit.disabled = true;
      notice(feedback, "Đang ghi nhận chuyển khoản…");
      try {
        await request("/me/wallet/bank-top-ups", { method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify(attempt) });
        attempt = null;
        form.reset();
        notice(feedback, "Đã nạp tiền vào ví.", "success");
        if (state.user === owner && state.mode === "client") loadClientWallet();
      } catch (error) {
        notice(feedback, error.publicMessage || "Chưa xác nhận được giao dịch nạp tiền. Hãy thử lại.", "error");
      } finally {
        submit.disabled = false;
      }
    });
  }

  const controller = new AbortController();
  walletRequest = controller;
  const entries = byId("wallet-entries");
  try {
    const wallet = await request("/me/wallet", { signal: controller.signal });
    if (walletRequest !== controller || state.user !== owner || state.mode !== "client") return;
    byId("wallet-balance").textContent = usd.format(wallet.balance);
    entries.replaceChildren();
    workflowList(entries, wallet.entries.map((row) => {
      const reference = row.contract_id ? `Hợp đồng #${row.contract_id}` : `Chuyển khoản #${row.entry_id}`;
      return summaryRow(walletLabels[row.kind], `${reference} · ${formatDay(row.created_at)}`,
        `${row.amount > 0 ? "+" : ""}${usd.format(row.amount)}`);
    }), "Chưa có giao dịch.");
  } catch (error) {
    if (error.name !== "AbortError" && walletRequest === controller && entries.isConnected) {
      entries.textContent = "Chưa tải được giao dịch trong ví.";
    }
  }
}

function resetContractPanel() {
  Object.assign(contractPanel, { tab: "progress", preview: "unbilled", week: null, invoice: null });
}

function contractButton(label, run, primary = false) {
  const button = textElement("button", `button ${primary ? "button-green" : "button-outline"}`, label);
  button.type = "button";
  button.addEventListener("click", run);
  return button;
}

function workflowAction(label, path, primary = false) {
  return contractButton(label, () => changeContract(path), primary);
}

function contractStatus(status) {
  const label = textElement("span", "contract-status", statusNames[status] || status);
  label.dataset.status = status;
  return label;
}

function workflowCard(title) {
  const section = textElement("section", "workflow-card", "");
  section.append(textElement("h3", "workflow-heading", title));
  return section;
}

function netSettlement(payments) {
  return payments.reduce((cents, row) => {
    if (row.status !== "SUCCEEDED") return cents;
    const amount = Math.round(row.amount * 100);
    if (row.transaction_type === "REVERSAL") return cents - amount;
    return ["ESCROW_RELEASE", "HOURLY_CHARGE"].includes(row.transaction_type) ? cents + amount : cents;
  }, 0) / 100;
}

function contractTotals(item) {
  const settled = Math.round(netSettlement(item.payments) * 100);
  const withheld = Math.round((item.cancellation?.withheld_penalty || 0) * 100);
  const paid = usd.format((settled - withheld) / 100);
  const sum = (rows, field) => rows.reduce((total, row) => total + Number(row[field]), 0);
  const eligible = item.time_entries?.filter((row) => row.eligibility_status === "ELIGIBLE") || [];
  const rows = item.contract_type === "HOURLY" ? [
    ["Đơn giá hợp đồng", `${usd.format(item.hourly_rate)}/giờ`],
    ["Giờ đủ điều kiện", `${hoursFormat.format(sum(eligible, "hours"))} giờ`],
    ["Chưa lập hóa đơn", usd.format(sum(item.unbilled_weeks, "amount"))],
    ["Đã chi ròng", paid],
  ] : [
    ["Giá trị hợp đồng", usd.format(item.agreed_amount)],
    ["Đang giữ ký quỹ", usd.format(sum(item.milestones.filter((row) =>
      row.funding_history.some((fund) => fund.status === "FUNDED")), "amount"))],
    ["Đã chi ròng", paid],
    item.cancellation ? ["Hoàn về ví", usd.format(item.cancellation.refunded_escrow)]
      : ["Chưa nạp ký quỹ", usd.format(sum(item.milestones.filter((row) => ["PLANNED", "REFUNDED"].includes(row.status)), "amount"))],
  ];
  const totals = textElement("dl", "contract-totals", "");
  for (const [label, value] of rows) {
    const metric = document.createElement("div");
    metric.append(textElement("dt", "", label), textElement("dd", "", value));
    totals.append(metric);
  }
  return totals;
}

function contractHeader(item, client) {
  const hero = textElement("div", "agreement-banner", "");
  const top = textElement("div", "agreement-banner-top", "");
  const badges = textElement("div", "agreement-badges", "");
  badges.append(textElement("span", "agreement-type", item.contract_type === "HOURLY" ? "Theo giờ" : "Trọn gói"),
    textElement("span", "agreement-id", `Hợp đồng #${item.contract_id}`), contractStatus(item.status));
  top.append(badges);
  if (client) {
    const states = {
      DRAFT: [["ACTIVE", "Bắt đầu hợp đồng"], ["TERMINATED", "Kết thúc hợp đồng"]],
      ACTIVE: [["COMPLETED", "Đánh dấu hoàn thành"], ["PAUSED", "Tạm dừng"], ["TERMINATED", "Kết thúc hợp đồng"]],
      PAUSED: [["ACTIVE", "Tiếp tục"], ["TERMINATED", "Kết thúc hợp đồng"]],
    };
    const controls = textElement("div", "row-actions agreement-controls", "");
    controls.append(...(states[item.status] || []).map(([status, label]) => workflowAction(label, `status/${status}`)));
    if (controls.childElementCount) top.append(controls);
  } else if (item.contract_type === "FIXED_PRICE" && ["ACTIVE", "PAUSED"].includes(item.status)
      && item.milestones.some((row) => !["APPROVED", "RELEASED"].includes(row.status))) {
    const button = contractButton("Hủy hợp đồng sớm", () => showCancellationQuote(item, button));
    button.classList.add("agreement-cancel");
    top.append(button);
  }
  const parties = textElement("dl", "agreement-parties", "");
  const fields = [
    ["Khách hàng", item.company_name],
    ["Freelancer", item.freelancer_name],
    ["Bắt đầu", formatDay(item.start_date)],
  ];
  if (item.end_date) fields.push(["Kết thúc", formatDay(item.end_date)]);
  for (const [label, value] of fields) {
    const pair = document.createElement("div");
    pair.append(textElement("dt", "", label), textElement("dd", "", value));
    parties.append(pair);
  }
  const art = textElement("div", "hero-art", "");
  art.setAttribute("aria-hidden", "true");
  art.append(...Array.from({ length: 4 }, () => document.createElement("i")));
  hero.append(top, textElement("h2", "agreement-title", item.title), parties, art);
  return hero;
}

function cancellationValues(data) {
  const values = textElement("dl", "invoice-preview-total cancellation-values", "");
  const net = (Math.round(data.gross_payout * 100) - Math.round(data.withheld_penalty * 100)) / 100;
  const rows = [
    ["Mốc đã nghiệm thu", `${data.completed_count}/${data.milestone_count}`],
    ["Đã nhận trước khi hủy", usd.format(data.already_paid)],
    ["Ký quỹ hoàn về ví khách hàng", usd.format(data.refunded_escrow)],
    [`Phí hủy (${hoursFormat.format(data.rate_percent)}%)`, usd.format(data.assessed_penalty)],
    ["Phí khấu trừ khi giải ngân", usd.format(data.withheld_penalty)],
    [data.penalty_paid_at ? "Phí đã trả qua ngân hàng" : "Phí còn phải trả", usd.format(data.outstanding_penalty)],
    ["Freelancer nhận thêm khi hủy", usd.format(net)],
  ];
  for (const [label, value] of rows) {
    const row = document.createElement("div");
    row.append(textElement("dt", "", label), textElement("dd", "", value));
    values.append(row);
  }
  return values;
}

async function showCancellationQuote(item, trigger) {
  if (trigger.disabled || state.savingContract) return;
  trigger.disabled = true;
  try {
    const quote = await request(`/contracts/${item.contract_id}/cancellation`);
    if (state.contract !== item || !trigger.isConnected) return;
    const dialog = textElement("dialog", "contract-cancel-dialog", "");
    dialog.setAttribute("aria-labelledby", "cancel-contract-title");
    const title = textElement("h3", "workflow-heading", "Hủy hợp đồng trọn gói");
    title.id = "cancel-contract-title";
    const back = contractButton("Quay lại", () => dialog.close());
    const confirm = contractButton("Xác nhận hủy hợp đồng", () => {
      dialog.close();
      changeContract("cancellation", { quote: quote.quote });
    }, true);
    const controls = textElement("div", "row-actions", "");
    controls.append(back, confirm);
    dialog.append(title, textElement("p", "contract-meta",
      "Phí hủy bằng 20% giá trị hợp đồng nhân với tỷ lệ mốc chưa nghiệm thu. Ký quỹ của mốc chưa nghiệm thu sẽ được hoàn, kể cả mốc đã nộp sản phẩm."),
      cancellationValues(quote), controls);
    dialog.addEventListener("close", () => dialog.remove(), { once: true });
    contractBody.append(dialog);
    dialog.showModal();
    back.focus();
  } catch (error) {
    if (state.contract === item) notice(contractFeedback, error.publicMessage || "Chưa tính được phí hủy.", "error");
  } finally {
    trigger.disabled = false;
  }
}

function renderContract() {
  const item = state.contract;
  const client = item.client_id === state.user.user_id;
  const tabs = textElement("div", "contract-switches contract-section-tabs", "");
  tabs.id = "contract-view-tabs";
  tabs.setAttribute("role", "group");
  tabs.setAttribute("aria-label", "Nội dung hợp đồng");
  for (const [key, label] of contractTabs) {
    const button = contractButton(label, () => showContractPanel(key));
    button.dataset.contractTab = key;
    button.setAttribute("aria-controls", "contract-panel");
    tabs.append(button);
  }
  const pane = document.createElement("div");
  pane.id = "contract-panel";
  const sections = [contractHeader(item, client), contractTotals(item)];
  if (item.cancellation) {
    const receipt = workflowCard("Đối soát hủy hợp đồng");
    receipt.append(cancellationValues(item.cancellation));
    if (!client && item.cancellation.outstanding_penalty > 0 && !item.cancellation.penalty_paid_at) {
      const actions = textElement("div", "row-actions cancellation-actions", "");
      actions.append(contractButton("Thanh toán phí hủy", () => {
        const amount = usd.format(item.cancellation.outstanding_penalty);
        if (window.confirm(`Xác nhận chuyển khoản mô phỏng ${amount} để thanh toán phí hủy?`)) {
          changeContract("cancellation/fee-payment");
        }
      }, true));
      receipt.append(actions);
    }
    sections.push(receipt);
  }
  contractBody.replaceChildren(...sections, tabs, pane);
  contractBody.hidden = false;
  showContractPanel(contractPanel.tab);
}

function showContractPanel(tab) {
  const item = state.contract;
  if (!item) return;
  contractPanel.tab = tab;
  for (const button of byId("contract-view-tabs").querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.contractTab === tab));
  }
  const client = item.client_id === state.user.user_id;
  const pane = byId("contract-panel");
  const builders = {
    progress: item.contract_type === "HOURLY" ? hourlyProgress : fixedProgress,
    history: contractHistory,
    reviews: contractReviews,
  };
  pane.replaceChildren(builders[tab](item, client));
}

function myReview(item, milestoneId = null) {
  return item.reviews.find((row) => row.reviewer_id === state.user.user_id && row.milestone_id === milestoneId);
}

function fixedProgress(item, client) {
  const container = workflowCard("Mốc bàn giao trọn gói");
  if (!item.milestones.length) container.append(textElement("p", "contract-meta", "Chưa có mốc bàn giao."));
  const list = textElement("ul", "milestone-list", "");
  for (const row of item.milestones) {
    const card = textElement("li", "milestone-card", "");
    card.dataset.milestoneId = row.milestone_id;
    const metadata = textElement("div", "milestone-meta", "");
    metadata.append(textElement("span", "", `Mốc ${row.sequence_no} · Hạn ${formatDay(row.due_date)}`), contractStatus(row.status));
    const head = textElement("div", "milestone-heading", "");
    head.append(textElement("h4", "", row.title), textElement("strong", "milestone-amount", usd.format(row.amount)));
    const step = { PLANNED: 1, REFUNDED: 1, FUNDED: 2, SUBMITTED: 3, APPROVED: 3, RELEASED: 4 }[row.status];
    if (step) {
      const steps = textElement("ol", "milestone-steps", "");
      milestoneSteps.forEach((label, index) => {
        const position = index + 1;
        const part = document.createElement("li");
        const done = position < step || (position === 4 && Boolean(myReview(item, row.milestone_id)));
        if (done) part.dataset.done = "true";
        if (!done && position === step) part.setAttribute("aria-current", "step");
        part.append(textElement("span", "step-index", String(position)), textElement("span", "", label));
        steps.append(part);
      });
      card.append(metadata, head, steps);
    } else {
      card.append(metadata, head);
    }
    const controls = milestoneControls(item, row, client);
    const funding = row.funding_history.at(-1);
    if (controls.length || funding) {
      const foot = textElement("div", "milestone-footer", "");
      if (funding) {
        const info = [`Ký quỹ #${funding.funding_id}`, funding.funded_at && `Nạp ${formatDay(funding.funded_at)}`,
          funding.released_at && `Giải ngân ${formatDay(funding.released_at)}`].filter(Boolean).join(" · ");
        foot.append(textElement("p", "contract-meta", info));
      }
      const actions = textElement("div", "row-actions", "");
      actions.append(...controls);
      foot.append(actions);
      card.append(foot);
    }
    list.append(card);
  }
  container.append(list);
  return container;
}

function milestoneControls(item, row, client) {
  if (row.status === "RELEASED") {
    return [contractButton(myReview(item, row.milestone_id) ? "Xem đánh giá" : "Gửi đánh giá", () => {
      showContractPanel("reviews");
      const section = byId(`milestone-review-${row.milestone_id}`);
      (section?.querySelector("input") || section)?.focus();
    })];
  }
  if (item.status !== "ACTIVE") return [];
  const path = `milestones/${row.milestone_id}`;
  if (!client) return row.status === "FUNDED" ? [workflowAction("Nộp sản phẩm", `${path}/submit`, true)] : [];
  const hasFunding = row.funding_history.some((fund) => fund.status === "PENDING");
  if (row.status === "PLANNED" || row.status === "REFUNDED") {
    if (hasFunding) return [workflowAction("Xác nhận trừ ví", `${path}/fund`, true), workflowAction("Hủy khoản đang chờ", `${path}/cancel-funding`)];
    const actions = [workflowAction("Nạp ký quỹ", `${path}/prepare-funding`, true)];
    if (row.status === "PLANNED") actions.push(workflowAction("Hủy mốc", `${path}/cancel`));
    return actions;
  }
  if (row.status === "FUNDED") return [workflowAction("Hoàn ký quỹ", `${path}/refund`)];
  if (row.status === "SUBMITTED") {
    return [workflowAction("Nghiệm thu và giải ngân", `${path}/approve-release`, true),
      workflowAction("Yêu cầu sửa", `${path}/request-changes`)];
  }
  if (row.status === "APPROVED") {
    const pending = item.payments.find((payment) => payment.milestone_id === row.milestone_id && payment.status === "PENDING");
    return pending ? paymentControls(item, pending) : [workflowAction("Giải ngân", `${path}/prepare-release`, true)];
  }
  return [];
}

function timeEditor() {
  const details = textElement("details", "contract-editor", "");
  details.append(textElement("summary", "", "Chấm công giờ làm mới"));
  const form = textElement("form", "work-form", "");
  form.append(contractField("start_at", "Bắt đầu", "datetime-local"), contractField("end_at", "Kết thúc", "datetime-local"),
    contractField("description", "Mô tả công việc", "textarea", { maxLength: 3000 }));
  const submit = textElement("button", "button button-green", "Lưu giờ làm");
  submit.type = "submit";
  form.append(submit);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form));
    data.start_at = new Date(data.start_at).toISOString();
    data.end_at = new Date(data.end_at).toISOString();
    changeContract("time", data, () => { contractPanel.preview = "unbilled"; });
  });
  details.append(form);
  return details;
}

function contractField(name, label, type, { required = true, ...limits } = {}) {
  const field = document.createElement("label");
  const input = document.createElement(type === "textarea" ? "textarea" : "input");
  input.name = name;
  if (type === "textarea") {
    input.rows = 3;
    field.classList.add("span-form");
  } else input.type = type;
  Object.assign(input, { required, ...limits });
  field.append(label, input);
  return field;
}

function tableCell(row, value) {
  const cell = document.createElement("td");
  if (value instanceof Node) cell.append(value);
  else cell.textContent = value;
  row.append(cell);
}

function timesheet(item, client) {
  const sheet = workflowCard("Bảng chấm công theo giờ");
  if (item.status === "ACTIVE" && !client) sheet.append(timeEditor());
  if (!item.time_entries.length) {
    sheet.append(textElement("p", "contract-meta", "Chưa có mục giờ làm."));
    return sheet;
  }
  const scroll = textElement("div", "timesheet-scroll", "");
  scroll.tabIndex = 0;
  scroll.setAttribute("aria-label", "Bảng giờ làm");
  const table = textElement("table", "timesheet", "");
  const headings = table.createTHead().insertRow();
  for (const name of ["Mã · Ngày", "Mô tả công việc", "Số giờ", "Giá trị", "Tính phí", "Hóa đơn"]) {
    const cell = textElement("th", "", name);
    cell.scope = "col";
    headings.append(cell);
  }
  const body = table.createTBody();
  const drafts = new Set(item.invoices.filter((row) => row.status === "DRAFT").map((row) => row.invoice_id));
  for (const entry of item.time_entries) {
    const row = body.insertRow();
    const date = textElement("div", "timesheet-date", "");
    date.append(textElement("strong", "", `#${entry.entry_id}`), textElement("span", "", formatDay(entry.start_at)));
    tableCell(row, date);
    const description = textElement("div", "timesheet-description", entry.description);
    if (entry.carryover_week) description.append(textElement("small", "", `Tính vào tuần ${formatDay(entry.carryover_week)}`));
    tableCell(row, description);
    tableCell(row, hoursFormat.format(entry.hours));
    tableCell(row, usd.format(entry.amount));
    const eligibility = textElement("div", "timesheet-eligibility", "");
    eligibility.append(contractStatus(entry.eligibility_status));
    if (item.status === "ACTIVE" && client && (!entry.invoice_id || drafts.has(entry.invoice_id))) {
      eligibility.append(workflowAction(entry.eligibility_status === "ELIGIBLE" ? "Loại giờ" : "Tính phí",
        `time/${entry.entry_id}/${entry.eligibility_status === "ELIGIBLE" ? "INELIGIBLE" : "ELIGIBLE"}`));
    }
    tableCell(row, eligibility);
    tableCell(row, entry.invoice_id ? `#${entry.invoice_id}` : "Chưa lập");
  }
  const totals = table.createTFoot().insertRow();
  const label = textElement("th", "", "Tổng đủ điều kiện");
  label.scope = "row";
  label.colSpan = 2;
  totals.append(label);
  tableCell(totals, `${hoursFormat.format(item.time_entries.filter((row) => row.eligibility_status === "ELIGIBLE")
    .reduce((sum, row) => sum + row.hours, 0))} giờ`);
  tableCell(totals, usd.format([...item.invoices, ...item.unbilled_weeks].reduce((sum, row) => sum + (row.amount || 0), 0)));
  const fill = totals.insertCell();
  fill.colSpan = 2;
  scroll.append(table);
  sheet.append(textElement("p", "contract-meta timesheet-scroll-note", "Vuốt ngang để xem giá trị, trạng thái và mã hóa đơn."), scroll);
  return sheet;
}

function invoiceControls(item, row, client) {
  if (item.status !== "ACTIVE") return [];
  const choices = client ? {
    ISSUED: [["approve", "Duyệt hóa đơn"], ["dispute", "Yêu cầu đối soát"]],
    DISPUTED: [["reopen", "Mở lại bản nháp"]],
    APPROVED: [["prepare-payment", "Thanh toán từ ví"]],
  } : { DRAFT: [["issue", "Gửi hóa đơn"]] };
  const pending = item.payments.find((payment) => payment.invoice_id === row.invoice_id && payment.status === "PENDING");
  if (pending) return paymentControls(item, pending);
  return (choices[row.status] || []).map(([action, label], index) =>
    workflowAction(label, `invoices/${row.invoice_id}/${action}`, index === 0));
}

function previewInvoice(item, client, pane) {
  const billed = contractPanel.preview === "billed";
  const choices = billed ? item.invoices : item.unbilled_weeks;
  const getKey = (row) => billed ? String(row.invoice_id) : row.billing_week;
  const selectedKey = billed ? contractPanel.invoice : contractPanel.week;
  const picked = choices.find((row) => getKey(row) === selectedKey) || choices[0];
  const header = textElement("div", "invoice-preview-header", "");
  header.append(textElement("h3", "", billed ? "Hóa đơn theo tuần" : "Dự thảo hóa đơn"),
    textElement("p", "", `Đơn giá ${usd.format(item.hourly_rate)}/giờ · Tối đa ${item.weekly_limit} giờ/tuần`));
  const inner = textElement("div", "invoice-preview-body", "");
  const switches = textElement("div", "contract-switches preview-switches", "");
  switches.setAttribute("role", "group");
  switches.setAttribute("aria-label", "Chọn loại xem trước hóa đơn");
  for (const [mode, label] of [["unbilled", "Giờ chưa lập hóa đơn"], ["billed", "Hóa đơn đã lập"]]) {
    const button = contractButton(label, () => {
      contractPanel.preview = mode;
      previewInvoice(item, client, pane);
      pane.querySelector('[aria-pressed="true"]').focus();
    });
    button.setAttribute("aria-pressed", String(contractPanel.preview === mode));
    switches.append(button);
  }
  inner.append(switches);
  if (!picked) {
    inner.append(textElement("p", "contract-meta", billed ? "Chưa có hóa đơn." : "Chưa có giờ đủ điều kiện để lập hóa đơn."));
    pane.replaceChildren(header, inner);
    return;
  }
  const selector = document.createElement("select");
  selector.id = "invoice-preview-selector";
  for (const row of choices) {
    selector.add(new Option(billed ? `#${row.invoice_id} · Tuần ${formatDay(row.period_start)}` : `Tuần ${formatDay(row.billing_week)}`, getKey(row)));
  }
  selector.value = getKey(picked);
  selector.addEventListener("change", () => {
    if (billed) contractPanel.invoice = selector.value;
    else contractPanel.week = selector.value;
    previewInvoice(item, client, pane);
    byId("invoice-preview-selector").focus();
  });
  const label = textElement("label", "invoice-select", billed ? "Chọn hóa đơn" : "Chọn tuần UTC");
  label.append(selector);
  inner.append(label);
  const lines = billed ? item.time_entries.filter((row) => row.invoice_id === picked.invoice_id)
    : item.time_entries.filter((row) => !row.invoice_id && row.eligibility_status === "ELIGIBLE" && row.billing_week === picked.billing_week);
  const entries = textElement("ul", "invoice-lines", "");
  for (const entry of lines) {
    const row = textElement("li", "invoice-line", "");
    const detail = textElement("div", "invoice-line-detail", "");
    detail.append(textElement("strong", "", entry.description),
      textElement("span", "", `${formatDay(entry.start_at)} · ${hoursFormat.format(entry.hours)} giờ`));
    row.append(detail, textElement("strong", "invoice-line-amount", usd.format(entry.amount)));
    entries.append(row);
  }
  inner.append(entries);
  const summary = textElement("dl", "invoice-preview-total", "");
  const values = [["Tổng giờ", picked.hours == null ? "—" : `${hoursFormat.format(picked.hours)} giờ`],
    ["Trạng thái", billed ? statusNames[picked.status] : "Chưa lập hóa đơn"], ["Tổng tiền", picked.amount == null ? "—" : usd.format(picked.amount)]];
  for (const [key, value] of values) {
    const row = document.createElement("div");
    row.append(textElement("dt", "", key), textElement("dd", "", value));
    summary.append(row);
  }
  inner.append(summary);
  const actions = textElement("div", "row-actions", "");
  if (billed) actions.append(...invoiceControls(item, picked, client));
  else if (item.status === "ACTIVE" && !client) {
    actions.append(contractButton("Lập hóa đơn tuần", () => changeContract("invoices", { period_start: picked.billing_week }, (result) => {
      contractPanel.preview = "billed";
      contractPanel.invoice = String(result.invoice_id);
    }), true));
  }
  if (actions.childElementCount) inner.append(actions);
  pane.replaceChildren(header, inner);
}

function hourlyProgress(item, client) {
  const layout = textElement("div", "hourly-workspace", "");
  const preview = textElement("aside", "invoice-preview", "");
  preview.setAttribute("aria-label", "Xem trước hóa đơn");
  previewInvoice(item, client, preview);
  layout.append(timesheet(item, client), preview);
  return layout;
}

function workflowList(card, rows, empty) {
  if (!rows.length) card.append(textElement("p", "contract-meta", empty));
  else {
    const list = textElement("ul", "contract-items", "");
    list.append(...rows);
    card.append(list);
  }
}

function paymentControls(item, row) {
  const path = `payments/${row.payment_id}`;
  const actions = [];
  if (row.status === "PENDING" && row.payer_id === state.user.user_id) {
    if (item.status === "ACTIVE" || row.transaction_type === "REVERSAL") {
      const label = row.transaction_type === "ESCROW_RELEASE" ? "Xác nhận giải ngân" : "Xác nhận trừ ví";
      actions.push(workflowAction(label, `${path}/result/SUCCEEDED`, true));
    }
    actions.push(workflowAction("Ghi nhận thất bại", `${path}/result/FAILED`));
  }
  if (row.status === "SUCCEEDED" && row.payee_id === state.user.user_id && !row.reversed && !row.net_cancellation_payout
      && ["ESCROW_RELEASE", "HOURLY_CHARGE"].includes(row.transaction_type)) {
    actions.push(workflowAction("Ghi giao dịch bù", `${path}/reverse`));
  }
  return actions;
}

function historyActions(row, buttons) {
  if (buttons.length) {
    const controls = textElement("div", "row-actions", "");
    controls.append(...buttons);
    row.append(controls);
  }
  return row;
}

function contractHistory(item, client) {
  const fragment = document.createDocumentFragment();
  if (item.contract_type === "HOURLY") {
    const invoices = workflowCard("Danh sách hóa đơn");
    workflowList(invoices, item.invoices.map((row) => {
      const amount = row.amount == null ? "Không còn giờ đủ điều kiện" : `${hoursFormat.format(row.hours)} giờ · ${usd.format(row.amount)}`;
      return historyActions(summaryRow(`Hóa đơn #${row.invoice_id} · Tuần ${formatDay(row.period_start)}`, amount,
        statusNames[row.status]), invoiceControls(item, row, client));
    }), "Chưa có hóa đơn.");
    fragment.append(invoices);
  } else {
    const funding = workflowCard("Lịch sử ký quỹ");
    workflowList(funding, item.milestones.flatMap((milestone) => milestone.funding_history.map((row) =>
      summaryRow(`Ký quỹ #${row.funding_id} · Mốc ${milestone.sequence_no}`,
        `${usd.format(milestone.amount)}${row.settled_at ? ` · ${formatDay(row.settled_at)}` : ""}`, statusNames[row.status]))),
      "Chưa có khoản ký quỹ.");
    fragment.append(funding);
  }
  const payments = workflowCard("Lịch sử giao dịch");
  workflowList(payments, item.payments.map((row) => {
    const references = [`#${row.payment_id}`, row.original_payment_id && `Bù cho #${row.original_payment_id}`,
      row.invoice_id && `Hóa đơn #${row.invoice_id}`, row.milestone_id && `Mốc #${row.milestone_id}`,
      row.net_cancellation_payout && "Trước khấu trừ phí hủy"].filter(Boolean);
    return historyActions(summaryRow(statusNames[row.transaction_type], `${references.join(" · ")} · ${usd.format(row.amount)} · ${formatDay(row.created_at)}`,
      statusNames[row.status]), paymentControls(item, row));
  }), "Chưa có giao dịch.");
  fragment.append(payments);
  return fragment;
}

function reviewDirections(item, milestoneId) {
  const directions = textElement("ul", "review-directions", "");
  for (const [id, label] of [[item.client_id, "Khách hàng đánh giá freelancer"], [item.freelancer_id, "Freelancer đánh giá khách hàng"]]) {
    const review = item.reviews.find((row) => row.reviewer_id === id && row.milestone_id === milestoneId);
    const row = textElement("li", "review-direction", "");
    row.append(textElement("h4", "", label));
    if (review) {
      const stars = textElement("strong", "review-rating", "★".repeat(review.rating) + "☆".repeat(5 - review.rating));
      stars.setAttribute("aria-label", `${review.rating} trên 5 sao`);
      row.append(stars,
        textElement("p", "contract-meta", `${review.reviewer} · ${formatDay(review.submitted_at)}`));
      if (review.comment) row.append(textElement("p", "review-comment", review.comment));
    } else row.append(textElement("p", "contract-meta", "Chưa có đánh giá."));
    directions.append(row);
  }
  return directions;
}

function reviewForm(milestoneId = null) {
  const form = textElement("form", "work-form contract-review-form", "");
  const rating = textElement("fieldset", "star-rating", "");
  rating.append(textElement("legend", "", "Chọn số sao"));
  for (let stars = 1; stars <= 5; stars += 1) {
    const label = textElement("label", "", "");
    const input = document.createElement("input");
    Object.assign(input, { type: "radio", name: "rating", value: String(stars), required: true });
    label.append(input, textElement("span", "", `${stars} ★`));
    rating.append(label);
  }
  form.append(rating, contractField("comment", "Nhận xét (tùy chọn)", "textarea", { required: false, maxLength: 3000 }));
  const submit = textElement("button", "button button-green", "Gửi đánh giá");
  submit.type = "submit";
  form.append(submit);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const data = new FormData(form);
    const path = milestoneId ? `milestones/${milestoneId}/reviews` : "reviews";
    changeContract(path, { rating: Number(data.get("rating")), comment: data.get("comment").trim() || null });
  });
  return form;
}

function contractReviews(item) {
  const card = workflowCard("Đánh giá hai chiều");
  if (item.contract_type === "HOURLY") {
    card.append(reviewDirections(item, null));
    if (item.status !== "COMPLETED") {
      card.append(textElement("p", "contract-meta", "Hai bên có thể gửi đánh giá sau khi hợp đồng hoàn thành."));
    } else if (!myReview(item)) {
      card.append(reviewForm());
    }
    return card;
  }
  const released = item.milestones.filter((row) => row.status === "RELEASED");
  if (!released.length) card.append(textElement("p", "contract-meta", "Có thể đánh giá từng mốc ngay sau khi mốc được giải ngân."));
  for (const milestone of released) {
    const section = textElement("section", "milestone-review", "");
    section.id = `milestone-review-${milestone.milestone_id}`;
    section.tabIndex = -1;
    section.append(textElement("h4", "", `Mốc ${milestone.sequence_no} · ${milestone.title}`),
      reviewDirections(item, milestone.milestone_id));
    if (!myReview(item, milestone.milestone_id)) section.append(reviewForm(milestone.milestone_id));
    card.append(section);
  }
  if (item.reviews.some((row) => row.milestone_id === null)) {
    const history = textElement("details", "contract-editor milestone-review", "");
    history.append(textElement("summary", "", "Đánh giá toàn hợp đồng trước đây"), reviewDirections(item, null));
    card.append(history);
  }
  return card;
}
