import ast
import math
import operator

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

BINARY_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
}


def _eval(node):
    """Safely evaluate a parsed arithmetic expression (no eval())."""
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)) \
            and not isinstance(node.value, bool):
        return float(node.value)
    if isinstance(node, ast.BinOp) and type(node.op) in BINARY_OPS:
        left, right = _eval(node.left), _eval(node.right)
        if isinstance(node.op, ast.Div) and right == 0:
            raise ZeroDivisionError("Cannot divide by zero")
        return BINARY_OPS[type(node.op)](left, right)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
        value = _eval(node.operand)
        return -value if isinstance(node.op, ast.USub) else value
    raise ValueError("Invalid expression")


def evaluate(expression: str) -> str:
    expression = expression.replace("×", "*").replace("÷", "/").replace("−", "-").strip()
    if not expression or len(expression) > 200:
        raise ValueError("Invalid expression")
    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError:
        raise ValueError("Invalid expression")
    value = _eval(tree.body)
    if not math.isfinite(value):
        raise ValueError("Number too large")
    return f"{value:.10g}"


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/calculate", methods=["POST"])
def calculate():
    data = request.get_json(silent=True) or {}
    try:
        return jsonify(result=evaluate(str(data.get("expression", ""))))
    except ZeroDivisionError as exc:
        return jsonify(error=str(exc)), 400
    except (ValueError, OverflowError):
        return jsonify(error="Invalid expression"), 400


# Health checks used by the AWS load balancer
@app.route("/health")
@app.route("/ping")
def health():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)