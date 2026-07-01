#!/usr/bin/env python3
# Distil a `wasm-tools json-from-wast` JSON into the manifest pair the
# zwasm WAST runners consume: manifest.txt (parse: valid/invalid/malformed)
# + manifest_runtime.txt (module/register/assert_return/assert_trap/invoke/...).
#
# Factored out of scripts/regen_wasmtime_misc.sh (ADR-0012 6.C) so both the
# curated-corpus regen AND the full misc_testsuite differential sweep
# (ADR-0192, scripts/wasmtime_misc_sweep.sh) share ONE distiller.
#
# Usage: wast_to_manifest.py <src.json> <dst_parse> <dst_runtime>
#
# D-290 tool-difference rules: wasm-tools emits i32/i64 SIGNED (sometimes as
# JSON numbers) — fold to the unsigned width the runner expects. Valid text
# modules sometimes come out `.wat`; the caller's copy loop parses those.
import json
import sys


def encode_value(v):
    ty = v.get('type', '')
    raw = v.get('value', '')
    if ty == 'i32':
        try:
            return f'i32:{int(raw) & 0xffffffff}'
        except Exception:
            return None
    if ty == 'i64':
        try:
            return f'i64:{int(raw) & 0xffffffffffffffff}'
        except Exception:
            return None
    if ty == 'f32':
        try:
            return f'f32:0x{int(raw) & 0xffffffff:08x}'
        except Exception:
            return None
    if ty == 'f64':
        try:
            return f'f64:0x{int(raw) & 0xffffffffffffffff:016x}'
        except Exception:
            return None
    # v128 / externref / funcref / null refs deferred — the runtime runner
    # doesn't compare those yet. None drops the whole directive.
    return None


def norm_wasm(fn):
    return fn[:-4] + '.wasm' if fn.endswith('.wat') else fn


def encode_args(values):
    out = []
    for v in values or []:
        e = encode_value(v)
        if e is None:
            return None
        out.append(e)
    return out


def quote_field(field):
    if any(c in field for c in ' \t"'):
        return '"' + field.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return field


TRAP_TAG_MAP = {
    'unreachable': 'Unreachable',
    'integer divide by zero': 'DivByZero',
    'divide by zero': 'DivByZero',
    'integer overflow': 'IntOverflow',
    'invalid conversion to integer': 'InvalidConversionToInt',
    'out of bounds memory access': 'OutOfBounds',
    'out of bounds': 'OutOfBounds',
    'out of bounds table access': 'OutOfBoundsTableAccess',
    'uninitialized element': 'UninitializedElement',
    'indirect call type mismatch': 'IndirectCallTypeMismatch',
    'call stack exhausted': 'StackOverflow',
    'undefined element': 'OutOfBoundsTableAccess',
    'null reference': 'NullReference',
    'cast failure': 'CastFailure',
}


def distil(src):
    d = json.load(open(src))
    parse_lines = []
    rt_lines = []
    for c in d['commands']:
        t = c.get('type')
        if t == 'module':
            fn = norm_wasm(c['filename'])
            parse_lines.append('valid ' + fn)
            line = 'module ' + fn
            name = c.get('name')
            if name:
                line += ' as ' + quote_field(str(name))
            rt_lines.append(line)
        elif t == 'register':
            line = 'register ' + quote_field(c.get('as', ''))
            name = c.get('name')
            if name:
                line += ' from ' + quote_field(str(name))
            rt_lines.append(line)
        elif t in ('assert_invalid', 'assert_malformed') and c.get('module_type') == 'binary':
            kind = 'invalid' if t == 'assert_invalid' else 'malformed'
            parse_lines.append(kind + ' ' + c['filename'])
        elif t in ('assert_unlinkable', 'assert_uninstantiable') and c.get('module_type') == 'binary':
            rt_lines.append(t + ' ' + c['filename'])
        elif t == 'assert_return':
            act = c.get('action', {})
            if act.get('type') != 'invoke':
                continue
            args = encode_args(act.get('args'))
            expected = encode_args(c.get('expected'))
            if args is None or expected is None:
                continue
            rt_line = 'assert_return ' + quote_field(act.get('field', ''))
            if args:
                rt_line += ' ' + ' '.join(args)
            rt_line += ' -> ' + (' '.join(expected) if expected else '')
            rt_lines.append(rt_line.rstrip())
        elif t == 'action':
            act = c.get('action', {})
            if act.get('type') != 'invoke':
                continue
            args = encode_args(act.get('args'))
            if args is None:
                continue
            rt_line = 'invoke ' + quote_field(act.get('field', ''))
            if args:
                rt_line += ' ' + ' '.join(args)
            rt_lines.append(rt_line.rstrip())
        elif t == 'assert_trap':
            act = c.get('action', {})
            if act.get('type') != 'invoke':
                continue
            args = encode_args(act.get('args'))
            if args is None:
                continue
            kind = TRAP_TAG_MAP.get(c.get('text', ''), 'Unreachable')
            rt_line = 'assert_trap ' + quote_field(act.get('field', ''))
            if args:
                rt_line += ' ' + ' '.join(args)
            rt_line += ' !! ' + kind
            rt_lines.append(rt_line)
    return parse_lines, rt_lines


def main():
    src, dst_parse, dst_rt = sys.argv[1], sys.argv[2], sys.argv[3]
    parse_lines, rt_lines = distil(src)
    with open(dst_parse, 'w') as f:
        f.write('\n'.join(parse_lines) + '\n')
    with open(dst_rt, 'w') as f:
        f.write('\n'.join(rt_lines) + '\n')


if __name__ == '__main__':
    main()
