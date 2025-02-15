# Test var / setvar / etc.

# TODO: GetVar needs a mode where Obj[str] gets translated to value.Str?
# Then all code will work.
#
# word_eval:
#
# val = self.mem.GetVar(var_name) ->
# val = GetWordVar(self.mem, var_name)
#
# Conversely, in oil_lang/expr_eval.py:
# LookupVar gives you a plain Python object.  I don't think there's any
# downside here.
#
# repr exposes the differences.
#
# Notes:
#
# - osh/cmd_exec.py handles OilAssign, which gets wrapped in value.Obj()
# - osh/word_eval.py _ValueToPartValue handles 3 value types.  Used in:
#   - _EvalBracedVarSub
#   - SimpleVarSub in _EvalWordPart
# - osh/expr_eval.py: _LookupVar wrapper should disallow using Oil values
#   - this is legacy stuff.  Both (( )) and [[ ]]
#   - LhsIndexedName should not reference Oil vars either


#### integers expression and augmented assignment
var x = 1 + 2 * 3
echo x=$x

setvar x += 4
echo x=$x
## STDOUT:
x=7
x=11
## END

#### setvar when variable isn't declared results in fatal error
var x = 1
f() {
  # setting global is OK
  setvar x = 2
  echo x=$x

  setvar y = 3  # NOT DECLARED
  echo y=$y
}
f
## status: 1
## STDOUT:
x=2
## END

#### var/setvar x, y = 1, 2

# Python doesn't allow you to have annotation on each variable!
# https://www.python.org/dev/peps/pep-0526/#where-annotations-aren-t-allowed
#var x Int, y Int = 3, 4
setvar x, y = 1, 2
echo $x $y
## STDOUT:
1 2
## END

#### setvar x[1] = 42
shopt -s all:oil
var mylist = [1,2,3]
setvar x[1] = 42
echo -sep ' ' @x
## STDOUT:
1 42 3
## END


#### duplicate var def results in fatal error
var x = "global"
f() {
  var x = "local"
  echo x=$x
}
f
var x = "redeclaration is an error"
## status: 1
## STDOUT:
x=local
## END

#### setvar dynamic scope (TODO: change this?)
modify_with_shell_assignment() {
  f=shell
}

modify_with_setvar() {
  setvar f = "setvar"
}

f() {
  var f = 1
  echo f=$f
  modify_with_shell_assignment
  echo f=$f
  modify_with_setvar
  echo f=$f
}
f
## STDOUT:
f=1
f=shell
f=setvar
## END

#### command sub $(echo hi)
var x = $(echo hi)
var y = $(echo '')
# Make sure we can operate on these values
echo x=${x:-default} y=${y:-default}
## STDOUT:
x=hi y=default
## END

#### shell array @(a 'b c')
shopt -s parse_at
var x = @(a 'b c')
var empty = @()
argv.py / @x @empty /

## STDOUT:
['/', 'a', 'b c', '/']
## END

#### empty array and simple_word_eval (regression test)
shopt -s parse_at simple_word_eval
var empty = @()
echo len=${#empty[@]}
argv.py / @empty /

## STDOUT:
len=0
['/', '/']
## END

#### Empty array and assignment builtin (regression)
# Bug happens with shell arrays too
empty=()
declare z=1 "${empty[@]}"
echo z=$z
## STDOUT:
z=1
## END

#### Shell arrays support tilde detection, static globbing, brace detection
shopt -s parse_at simple_word_eval
touch {foo,bar}.py
HOME=/home/bob
no_dynamic_glob='*.py'

var x = @(~/src *.py {andy,bob}@example.com $no_dynamic_glob)
argv.py @x
## STDOUT:
['/home/bob/src', 'bar.py', 'foo.py', 'andy@example.com', 'bob@example.com', '*.py']
## END

#### augmented assignment doesn't work on shell arrays
shopt -s parse_at simple_word_eval
var x = @(a 'b c')
argv.py @x

setvar x += @(d e)  # fatal error
argv.py @x
## status: 1
## STDOUT:
['a', 'b c']
## END

#### Splice in a Python list (i.e. Oil Obj var in word evaluator)
shopt -s parse_at simple_word_eval
var mylist = ["one", "two"]
argv.py @mylist
## STDOUT:
['one', 'two']
## END

#### Can't splice undefined
shopt -s all:oil
argv.py @undefined
echo done
## status: 1
## stdout-json: ""

#### Set $HOME using 'var' (i.e. Oil string var in word evaluator)
var HOME = "foo"
echo $HOME
echo ~
## STDOUT:
foo
foo
## END

#### Use shell var in Oil expression
x='abc'
var length = len(x)  # length in BYTES, unlike ${#x}
echo $length
## STDOUT:
3
## END

#### Length in two different contexts
x=(a b c)
x[10]=A
x[20]=B

# shell style: length is 5
echo shell=${#x[@]}

# Oil function call: length is 20.  I think that makes sense?  It's just a
# different notion of length.
echo oil=$len(x)

## STDOUT:
shell=5
oil=21
## END

#### $len(x) inside strings
var s = "abc"
echo -$len(s)-

# This already has a meaning ...
#echo "-$len(x)-"
#echo "-${len}(x)-"

## STDOUT:
-3-
## END

#### Func with multiple args in multiple contexts
var x = max(1+2, 3+4)
echo $x $max(1+2, 3+4)

## STDOUT:
7 7
## END


#### Trailing Comma in Param list
var x = max(1+2, 3+4,)
echo $x $max(1+2, 3+4,)

## STDOUT:
7 7
## END

#### @split(x) 
shopt -s all:oil
setvar IFS = ":"
var x = "one:two:three"
argv.py @split(x)
## STDOUT:
['one', 'two', 'three']
## END

#### @range()
shopt -s all:oil
echo @range(10, 15, 2)
## STDOUT:
10
12
14
## END

#### Wrong sigil $range() shows representation of iterator?
shopt -s all:oil
echo $range(10, 15, 2)
## STDOUT:
TODO
## END

#### Wrong sigil @max(3, 4)
shopt -s all:oil
echo @max(3, 4)
## STDOUT:
TODO
## END


#### nested expr contexts
var s = "123"

# lex_mode_e.ShCommand -> Expr -> ShCommand -> Expr
var x = $(echo 'len\n' $len(s))
echo $x
## STDOUT:
len
3
## END


# TODO:
# - test keyword args
# - test splatting *args, **kwargs
# - Multiline parsing
#
# var x = max(
#   1+2,
#   3+4,
# )
# echo $x $max(
#   1+2,
#   3+4,
# )

#### Test value.Obj inside shell arithmetic
var w = "3"
echo lt=$(( w < 4 ))
echo gt=$(( w > 4 ))

var z = 3
echo lt=$(( z < 4 ))
echo gt=$(( z > 4 ))
## STDOUT:
lt=1
gt=0
lt=1
gt=0
## END

#### Parse { setvar x = 1 }
shopt -s all:oil
var x = 1
f() { setvar x = 2 }
f
echo x=$x
## STDOUT:
x=2
## END

#### double quoted
var foo = "bar"
var x = "-$foo-${foo}-${undef:-default}-"
echo $x
## STDOUT:
-bar-bar-default-
## END

#### double quoted respects strict_array
shopt -s all:oil
var a = @(one two three)
var x = "-${a[@]}-"
echo $x
## status: 1
## stdout-json: ""

#### single quoted -- implicit and explicit raw
var x = 'foo bar'
echo $x
setvar x = r'foo bar'  # Same string
echo $x
setvar x = r'\t\n'  # This is raw
echo $x
## STDOUT:
foo bar
foo bar
\t\n
## END

#### Implicit raw single quote with backslash is a syntax error
var x = '\t\n'
echo $x
## status: 2
## stdout-json: ""

#### single quoted C strings: c'foo\n' and $'foo\n'
var x = c'foo\nbar'
echo "$x"
var y = $'foo\nbar'
echo "$y"
## STDOUT:
foo
bar
foo
bar
## END

#### simple var sub $name $0 $1 $? etc.
( exit 42 )
var status = $?
echo status=$status

set -- a b c
var one = $1
var two = $2
echo $one $two

var named = $one  # equivalent to 'one'
echo named=$named

## STDOUT:
status=42
a b
named=a
## END

#### braced var sub ${x:-default}

# without double quotes

var b = ${foo:-default}
echo $b
var c = ${bar:-"-$b-"}
echo $c

var d = "${bar:-"-$c-"}"  # another one
echo $d

## STDOUT:
default
-default-
--default--
## END

#### braced var sub respects strict_array
set -- a b c
var x = ${undef:-"$@"}
echo $x
shopt -s strict_array
setvar x = ${undef:-"$@"}
echo $x
## status: 1
## STDOUT:
a b c
## END


#### null / true / false
shopt -s all:oil
var n = null
if (n) {
  echo yes
} else {
  echo no
}
var t = true
if (t) {
  echo yes
} else {
  echo no
}
var f = false
if (f) {
  echo yes
} else {
  echo no
}
## STDOUT:
no
yes
no
## END

#### Integer literals
var d = 123
var b = 0b11
var o = 0o123
var h = 0xff
echo $d $b $o $h
## STDOUT:
123 3 83 255
## END

#### Float Literals
shopt -s all:oil
# 1+2 2.3
var x = 1.2 + 23.0e-1  # 3.5
if (x < 3.9) {
  echo less
}
if (x > 3.4) {
  echo great
}
## STDOUT:
less
great
## END

#### Float Literals with _ (requires re2c refinement)
shopt -s all:oil
# 1+2 + 2.3
# add this _ here
var x = 1.2 + 2_3.0e-1  # 3.5
if (x < 3.9) {
  echo less
}
if (x > 3.4) {
  echo great
}
## STDOUT:
less
great
## END

#### Tuples
var zero = ()

# TODO: I don't like this trailing comma syntax?
var one = 1,
var one2 = (1,)
var two = (1,2)
echo $len(zero)
echo $len(one)
echo $len(one2)
echo $len(two)
## STDOUT:
0
1
1
2
## END

#### List comprehension
shopt -s all:oil

var n = [i*2 for i in range(5)]
echo -sep ' ' @n

# TODO: Test this
#var n = [i*2 for i,j in range(5)]

var even = [i*2 for i in range(5) if i % 2 == 0]
echo -sep ' ' @even
## STDOUT:
0 2 4 6 8
0 4 8
## END

#### in, not in
var d = [1,2,3]
var b = 1 in d
echo $b
setvar b = 0 in d
echo $b
setvar b = 0 not in d
echo $b
## STDOUT:
True
False
True
## END

#### Chained Comparisons
shopt -s all:oil
if (1 < 2 < 3) {
  echo '123'
}
if (1 < 2 <= 2 <= 3 < 4) {
  echo '123'
}

if (1 < 2 < 2) {
  echo '123'
} else {
  echo 'no'
}
## STDOUT:
123
123
no
## END

#### dict with 'bare word' keys
var d0 = {}
echo len=$len(d0)
var d1 = {name: "hello"}
echo len=$len(d1)
var d2 = {name: "hello", other: 2}
echo len=$len(d2)
## STDOUT:
len=0
len=1
len=2
## END

#### dict with expression keys
var d1 = {['name']: "hello"}
echo len=$len(d1)
var v = d1['name']
echo $v

var key='k'
var d2 = {["$key"]: "bar"}
echo len=$len(d2)
var v2 = d2['k']
echo $v2

## STDOUT:
len=1
hello
len=1
bar
## END


#### dict literal with implicit value
var name = 'foo'
var d1 = {name}
echo len=$len(d1)
var v1 = d1['name']
echo $v1

var d2 = {name, other: 'val'}
echo len=$len(d2)
var v2 = d2['name']
echo $v2

## STDOUT:
len=1
foo
len=2
foo
## END

#### Dict literal with string keys
var d = {'sq': 123}
var v = d['sq']
echo $v

var x = "q"
var d2 = {"d$x": 456}
var v2 = d2["dq"]
echo $v2
## STDOUT:
123
456
## END

#### Bitwise logical
var a = 0b0101 & 0b0011
echo $a
var b = 0b0101 | 0b0011
echo $b
var c = 0b0101 xor 0b0011
echo $c
var d = ~b
echo $d
## STDOUT:
1
7
6
-8
## END

#### Shift operators
var a = 1 << 4
echo $a
var b = 16 >> 4
echo $b
## STDOUT:
16
1
## END

#### Exponent is ^
var x = 2^3
echo $x
var y = 2.0^3.0
echo $y
## STDOUT:
8
8.0
## END

#### Two Kinds of Division
var x = 5/2
echo $x
var y = 5 div 2
echo $y
## STDOUT:
2.5
2
## END

#### Logical operators
var a = not true
echo $a
var b = true and false
echo $b
var c = true or false
echo $c

# TODO: These should be spelled 'false' 'false' 'true'?

## STDOUT:
False
False
True
## END

#### x if b else y
var b = true
var i = 42
var t = i+1 if b else i-1
echo $t
var f = i+1 if false else i-1
echo $f
## STDOUT:
43
41
## END

#### multiline strings, dict, list, tuples, etc.
var dq = "
dq
2
"
echo dq=$len(dq)

var sq = '
sq
2
'
echo sq=$len(sq)

var mylist = [
  1,
  2,
  3,
]
echo mylist=$len(mylist)

var mydict = { a:1,
  b:
  2,
}
echo mydict=$len(mydict)

var mytuple = (1,
  2, 3)
echo mytuple=$len(mytuple)

## STDOUT:
dq=6
sq=6
mylist=3
mydict=2
mytuple=3
## END

#### multiline array and command sub (only here docs disallowed)
var array = @(
  one
  two
  three
)
echo array=$len(array)

var comsub = $(
echo hi
echo bye
)
echo comsub=$len(comsub)

## STDOUT:
array=3
comsub=6
## END

#### s ~ regex and s !~ regex
shopt -s all:oil

var s = 'foo'
if (s ~ '.([[:alpha:]]+)') {  # ERE syntax
  echo matches
  argv.py @M
}
if (s !~ '[[:digit:]]+') {
  echo "does not match"
  argv.py @M
}

if (s ~ '[[:digit:]]+') {
  echo "matches"
}
# Should be cleared now
argv.py @M

## STDOUT:
matches
['foo', 'oo']
does not match
['foo', 'oo']
[]
## END

#### s ~ regex sets a local, not a global
shopt -s all:oil
proc f {
  if ('foo' ~ '.([[:alpha:]]+)') {  # ERE syntax
    echo matches
    argv.py @M
  }
}
f
echo ${M:-default}
## STDOUT:
matches
['foo', 'oo']
default
## END


#### M can be saved and used later
shopt -s all:oil

var pat = '.([[:alpha:]]+)'  # ERE syntax
if ('foo' ~ pat) {
  var m1 = M
  if ('bar' ~ pat) {
    var m2 = M
  }
}
argv.py @m1
argv.py @m2
## STDOUT:
['foo', 'oo']
['bar', 'ar']
## END


#### obj.attr and obj.method()
var s = 'hi'

# TODO: This does a bound method thing we probably don't want
var s2 = s.upper()
echo $s2
## STDOUT:
HI
## END

#### obj.method does NOT give you a bound method

# TODO: Not sure how to implement this

var s = 'hi'
var method = s.upper
echo $method
## STDOUT:
## END



#### d->key
var d = {name: 'andy'}
var x = d->name
echo $x
## STDOUT:
andy
## END
