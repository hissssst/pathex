# Changelog

## 2.1

**Breaking**

* Updating and viewing keywords with `star` and `some` lenses now doesn't raise when they're used against non-proper keyword

**Non-breaking**

* Concatenated paths now can force_over for not only maps
* Fixed debug lens
* Added ability to pass calls and arbitary structures into `path` macro
* Unrolled some clauses for `star` and `some` for extra efficiency

## 2.0

**Breaking**

* Reworked `star` lens. Now it is less optimistic and returns `:error` when no values were viewed/updated
* Removed sigils
* Removed deprecated lens `id`
* Removed deprecated lens `either`
* Removed `recur` function

**Non-breaking**

* `compose` function for recursive lens
* `delete` method for all paths, lenses and higher order functions
* `inspect` method for all paths, lenses and higher order functions
* Matchable updater for lists and maps
* Builders are selected for combination (not for mod as they used to)
* Reworked documentation
* Annotated paths

## 1.3.0

**Breaking**

None! __(See deprecated in Non-breaking)__

**Non-breaking**

* Deprecated `id` lens
* Deprecated `either` lens

* Fixed bug with concatenation context overlapping
* `some` lens
* `star` lens
* `matching` lens
* `filtering` lens
* Removed some dead code
* Moved lenses code to separate modules

## 1.2.0

**Breaking**

None!

**Non-breaking**

* `star` lens
* `all` lens

## 1.1.0

**Breaking**

None!

**Non-breaking**

* `|||` operator
* stack-optimized version of `~>` operator
* stack-optimized version of `|||` operator

## 1.0.0

**Breaking**

* `force_set`/`get`/`set` clause in closure was renamed to `force_update`/`view`/`update`
and added a special argument with default value in it

**Non-breaking**

* `alongside` macro
* stack-optimized version of `&&&` operator
* path code generation size assertion
* better documentation format
* `id` lens
* `either` lens
* `any` lens

> Yeah, it starts from 1.0.0
> I can describe previous versions if anybody needs this. Just open an issue! :)
