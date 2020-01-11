# Change Log

## [0.7.2] - Released on 2020-01-11

- Rewrote cleanup logic

## [0.7.1] - Released on 2019-12-25

- Fixed serialization issue

## [0.7.0] - Released on 2019-10-19

- Added `namespace` to support multiple instances
- Breaking Changes:
  - Removed static `CacheStore.setPolicy` method
  - Moved `CacheStore.fetch` to instance field
  - Renamed `CacheStore.getInstance` parameter `httpGetter` to `fetch`

### Upgrade Guide

1. remove `CacheStore.setPolicy` and set the policy in `CacheStore.getInstance`. For example, `CacheStore.getInstance(policy: LessRecentlyUsedPolicy(maxCount: 4096))`
2. if `httpGetter: myFetch` is used in `CacheStore.getInstance`, rename it to `fetch: myFetch`
3. any `CacheStore.fetch = myFetch` should be `store.fetch = myFetch`

For instance, old API:

```diff
void foo() async {
- CacheStore.setPolicy(LessRecentlyUsedPolicy(maxCount: 4096)); // 1
  CacheStore store = await CacheStore.getInstance(
+   policy: LessRecentlyUsedPolicy(maxCount: 4096), // 1
    clearNow: true,
-   httpGetter: bar, // 2
+   fetch: bar, // 2
  );

- CacheStore.fetch = baz; // 3
+ store.fetch = baz; // 3
}
```

## [0.6.0] - Released on 2019-07-08

- Fixed a bug `CacheStore.fetch` not working.
- Added optional `CustomFetch fetch` parameter to `getFile`.

## [0.5.0] - Released on 2019-06-19

- Nothing but dependencies upgrade

## [0.4.0] - Released on 2019-02-06

- Added `CustomFetch` support:
  - Now you can use custom function to fetch data instead of `http.get`.
  - Added named optional parameter `Map<String, dynamic> custom` to `getFile`, so you can pass custom data to your custom fetch function.

## [0.3.2+2] - Released on 2019-01-20

- Fixed stupid Health suggestions.

## [0.3.2] - Released on 2019-01-15

- First official release. Nothing changed.

## [0.3.1-RC2] - Released on 2018-12-08

- Fixed deprecated `int.parse`.

## [0.3.0-RC2] - Released on 2018-12-08

- Added inline documents.
- `LessRecentlyUsedPolicy` has been tested for a while and worked pretty well.

## [0.3.0-RC1] - Updated on 2018-11-24

- Added `LeastFrequentlyUsedPolicy`, `CacheControlPolicy` and `FifoPolicy`.
- File structure changes.
- Checking `maxCount` parameter now.

## [0.2.0-beta2] - Released on 2018-11-10

### Breaking Changes

- Changed interface of `CacheStorePolicy.generateFilename` to make it easier to customize your own cache file structure.

### Others

- Updated document and example.
- Fixed some bugs.

---

## [0.1.3-beta] - Released on 2018-11-10

- Some bug fixes.
- Document updates.
- Better 0 size files handling.

---

## [0.1.1-beta] - Released on 2018-11-04

- Finished basic designs.
- Updated documentation to match requirements
- Started to use in my own project.
