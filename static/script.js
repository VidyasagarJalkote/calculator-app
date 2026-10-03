(() => {
  const exprEl = document.getElementById("expr");
  const resultEl = document.getElementById("result");
  const OPS = ["+", "−", "×", "÷"];
  const isOp = (c) => OPS.includes(c);
  const lastNumber = () => expr.split(/[+−×÷]/).pop();

  let expr = "";
  let done = false; // true right after "=" was pressed

  function show(main, small = "") {
    resultEl.textContent = main || "0";
    exprEl.textContent = small;
    const len = resultEl.textContent.length;
    resultEl.className = "result" + (len > 14 ? " tiny" : len > 8 ? " small" : "");
  }

  function input(ch) {
    if (done) {
      if (!isOp(ch)) expr = "";
      done = false;
    }
    if (isOp(ch)) {
      if (expr === "") { if (ch !== "−") return; }
      else if (isOp(expr.at(-1))) {
        expr = expr.slice(0, -1);
        if (expr === "" && ch !== "−") return;
      }
    } else if (ch === ".") {
      if (lastNumber().includes(".")) return;
      if (lastNumber() === "") ch = "0.";
    } else if (lastNumber() === "0") {
      expr = expr.slice(0, -1); // avoid leading zeros like 05
    }
    expr += ch;
    show(expr);
  }

  function percent() {
    const m = expr.match(/(\d+\.?\d*)$/);
    if (!m) return;
    expr = expr.slice(0, m.index) + String(parseFloat(m[1]) / 100);
    done = false;
    show(expr);
  }

  function back() {
    if (done) { expr = ""; done = false; show("0"); return; }
    expr = expr.slice(0, -1);
    show(expr);
  }

  function clear() { expr = ""; done = false; show("0"); }

  async function equals() {
    if (!expr || isOp(expr.at(-1))) return;
    try {
      const res = await fetch("/calculate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ expression: expr }),
      });
      const data = await res.json();
      if (!res.ok) { show("Error", data.error); expr = ""; done = false; return; }
      show(data.result, expr + " =");
      expr = data.result.replace(/^-/, "−");
      done = true;
    } catch {
      show("Error", "Server not reachable");
      expr = "";
    }
  }

  const actions = { clear, back, percent, equals };

  document.getElementById("keys").addEventListener("click", (e) => {
    const btn = e.target.closest("button");
    if (!btn) return;
    if (btn.dataset.key) input(btn.dataset.key);
    else actions[btn.dataset.action]();
  });

  document.addEventListener("keydown", (e) => {
    const map = { "*": "×", "/": "÷", "-": "−", "+": "+", ".": "." };
    if (/^\d$/.test(e.key)) input(e.key);
    else if (map[e.key]) { e.preventDefault(); input(map[e.key]); }
    else if (e.key === "Enter" || e.key === "=") { e.preventDefault(); equals(); }
    else if (e.key === "Backspace") back();
    else if (e.key === "Escape") clear();
    else if (e.key === "%") percent();
  });
})();
