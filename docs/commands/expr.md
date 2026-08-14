# expr

## Name
`expr` - evaluate arguments as an expression.

## Synopsis
`expr expression`

## Description
Evaluates the supplied argument vector as a single expression and writes the result.

## Operands
`expression`: expression tokens supplied as separate command-line arguments.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized only by the common command wrapper.

## Standard Input
Not used.

## Standard Output
The expression result followed by one newline.

## Standard Error
Diagnostics for invalid expressions, invalid arithmetic operands, division by zero, and invalid regular expressions.

## Exit Status
`0` expression result is neither null nor `0`, `1` expression result is null or `0`, `2` invalid expression,
`125` internal failure.

## Behavioral Details
The V1 evaluator supports literals, parentheses, `|`, `&`, comparisons, `+`, `-`, `*`, `/`, `%`, `:` regular
expression matching, and the `length`, `index`, `substr`, and `match` string operators. Arithmetic uses checked
signed 64-bit integer operations. Comparisons are numeric when both operands are valid integers and lexical otherwise.

## Locale Behavior
Help and diagnostics are localized. Expression syntax, arithmetic, regex patterns, and result data are not localized.

## Implementation-Defined Choices
Regular expression matching is anchored at the beginning of the left operand and uses the project-owned BRE matcher.
The V1 matcher supports literals, `.`, `*`, bracket ranges and negation, escaped literals, and first subexpression
capture. POSIX escaped grouping `\(` and `\)` is supported; bare grouping is also accepted for compatibility with
earlier V1 tests. When the pattern has a capturing group, the first captured text is returned; otherwise the matched
length is returned.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`expr 1 + 2`

`expr abc : 'a.*'`

## Conformance Status
Conforming with implementation-defined behavior tracked by `EXPR-POSIX-001`.

## Known Limitations
Advanced locale-dependent bracket classes and collating elements are not implemented in V1.
