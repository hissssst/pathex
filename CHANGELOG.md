# Changelog

> Yeah, it starts from 1.0.0
> I can describe previous versions if anybody needs this. Just open an issue! :)

---

## 2.0

**Breaking**

* Reworked `star` lens. Now it is less optimistic and returns `:error` when no values were viewed/updated
* Removed sigils
* Removed deprecated lens `id`
* Removed deprecated lens `either`

**Non-breaking**

* `delete` method for all paths, lenses and higher order functions
* `inspect` method for all paths, lenses and higher order functions
* Matchable updater for lists and maps
* Builders are selected for combination (not for mod as they used to)

---

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

---

## 1.2.0

**Breaking**

None!

**Non-breaking**

* `star` lens
* `all` lens

---

## 1.1.0

**Breaking**

None!

**Non-breaking**

* `|||` operator
* stack-optimized version of `~>` operator
* stack-optimized version of `|||` operator

---

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
