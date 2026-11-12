// The Python that runs inside Pyodide for the classroom's Python console and
// editor. Kept apart from the worker so it can be tested in Node
// (vendor/lab-src/test). It answers in the same shape as the Ruby harness.
export const PY_SETUP = String.raw`
import ast, builtins, codeop, contextlib, io, json, sys, traceback

__iw_console_ns = {"__name__": "__main__"}
__iw_program_ns = {"__name__": "__main__"}
__iw_compile = codeop.CommandCompiler()


def __iw_no_input(prompt=""):
    raise RuntimeError("input() doesn't work in the browser. Put the value in a variable instead.")


builtins.input = __iw_no_input


def __iw_line(err, filename):
    if isinstance(err, SyntaxError):
        return err.lineno if err.filename == filename else None
    line = None
    for frame in traceback.extract_tb(err.__traceback__):
        if frame.filename == filename:
            line = frame.lineno
    return line


def __iw_friendly(err, filename="main.py"):
    line = __iw_line(err, filename)
    at = f" on line {line}" if line else ""
    if isinstance(err, IndentationError):
        return f"Python couldn't read your code{at}: the spaces at the start of the line don't line up. Lines inside a block need the same indent."
    if isinstance(err, SyntaxError):
        return f"Python couldn't read your code{at}. Look for a missing colon, quote or bracket."
    if isinstance(err, NameError):
        name = getattr(err, "name", None) or "that name"
        return f"Python doesn't know what {name} is{at}. Is it spelled right, and was it set before this line?"
    if isinstance(err, ZeroDivisionError):
        return f"Your code divided by zero{at}."
    if isinstance(err, KeyError):
        return f"There is no key {err.args[0]!r} in that dictionary{at}."
    if isinstance(err, IndexError):
        return f"That position is past the end of the list or string{at}."
    if isinstance(err, AttributeError):
        if "'NoneType'" in str(err):
            return f"Something{at} is None, so it has nothing called {getattr(err, 'name', '?')}. Did a function print instead of returning a value?"
        kind = {"str": "text", "list": "a list", "dict": "a dictionary", "int": "a whole number", "float": "a number"}.get(type(getattr(err, "obj", None)).__name__, "that value")
        raw = __iw_raw(err)
        hint = raw.split("Did you mean: ")[-1].rstrip("?").strip("'") if "Did you mean: " in raw else None
        return f"{kind[0].upper()}{kind[1:]} has nothing called {getattr(err, 'name', '?')}{at}." + (f" Did you mean {hint}?" if hint else "")
    if isinstance(err, TypeError):
        return f"Python can't do that with those kinds of values{at}: {err}"
    if isinstance(err, RecursionError):
        return f"A function kept calling itself and never stopped{at}."
    return f"{type(err).__name__}{at}: {err}"


def __iw_raw(err):
    return "".join(traceback.format_exception_only(type(err), err)).strip().splitlines()[-1]


def __iw_error(err, filename="main.py"):
    return {"friendly": __iw_friendly(err, filename), "raw": __iw_raw(err)}


# A check's expected value is written by the faculty as Python: a literal
# ("auto", 12, None) or a small expression ("b" * 20). If it is neither, it is
# compared as plain text.
def __iw_expected(text):
    try:
        return ast.literal_eval(str(text))
    except Exception:
        pass
    try:
        return eval(str(text), {"__builtins__": {}})
    except Exception:
        return text


def __iw_capture(fn):
    out = io.StringIO()
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            return out.getvalue, fn(), None
    except KeyboardInterrupt:
        raise
    except BaseException as err:  # SystemExit included: exit() must not stop the harness
        return out.getvalue, None, err


def __iw_checks(checks, ns, missing):
    answers = []
    for check in checks:
        kind = check.get("type")
        if kind not in ("method_returns", "value_is", "method_stdout_empty"):
            answers.append(None)
            continue
        out, value, err = __iw_capture(lambda: eval(check.get("call") or "", ns))
        printed = out()
        if kind == "method_stdout_empty":
            answers.append({"ok": err is None and printed == "", "expected": "(prints nothing)",
                            "actual": __iw_friendly(err, "check.py") if err else (printed or "(prints nothing)")})
        else:
            expected = __iw_expected(check.get("expected"))
            same = err is None and type(value) is type(expected) and value == expected
            # 1 == True and 1 == 1.0 in Python; a check for 1 should not pass on True.
            if err is None and not same and isinstance(expected, (int, float)) and isinstance(value, (int, float)):
                same = not isinstance(value, bool) and not isinstance(expected, bool) and value == expected
            answers.append({"ok": same, "expected": repr(expected),
                            "actual": (missing or __iw_friendly(err, "check.py")) if err else repr(value)})
    return answers


def __iw_run(payload_json):
    payload = json.loads(payload_json)
    global __iw_program_ns
    __iw_program_ns = {"__name__": "__main__"}

    def program():
        exec(compile(payload["code"], "main.py", "exec"), __iw_program_ns)

    out, _value, err = __iw_capture(program)
    return json.dumps({"stdout": out(), "error": __iw_error(err) if err else None,
                       "checks": __iw_checks(payload.get("checks") or [], __iw_program_ns, None)})


def __iw_console(payload_json):
    payload = json.loads(payload_json)
    global __iw_console_ns
    if payload["op"] == "reset":
        __iw_console_ns = {"__name__": "__main__"}
        return "{}"
    if payload["op"] == "values":
        return json.dumps({"checks": __iw_checks(payload.get("checks") or [], __iw_console_ns, "not there yet")})

    source = payload.get("line") or ""
    try:
        code = __iw_compile(source, "main.py", "single")
    except (SyntaxError, OverflowError, ValueError) as err:
        return json.dumps({"stdout": "", "value": None, "incomplete": False, "error": __iw_error(err)})
    if code is None:  # an open block, bracket or string: wait for more lines
        return json.dumps({"stdout": "", "value": None, "incomplete": True, "error": None})

    shown = []

    def hook(value):
        if value is not None:
            __iw_console_ns["_"] = value
            try:
                shown.append(repr(value))
            except Exception:
                shown.append("(a value that can't be shown)")

    old_hook, sys.displayhook = sys.displayhook, hook
    try:
        out, _value, err = __iw_capture(lambda: exec(code, __iw_console_ns))
    finally:
        sys.displayhook = old_hook
    friendly = err and {"friendly": __iw_friendly(err).replace(" on line 1", ""), "raw": __iw_raw(err)}
    return json.dumps({"stdout": out(), "value": "\n".join(shown) if shown else None, "incomplete": False, "error": friendly})
`
