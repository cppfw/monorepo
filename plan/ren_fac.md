# Plan: render context redesign — `factory` approach (ruis issue #190)

Issue: https://github.com/cppfw/ruis/issues/190 — "render context redesign"

## Summary

Split object creation out of `ruis::render::context` into a new
`ruis::render::factory` class. The **factory *is* the shared render context**
under the hood (the headless GL context for OpenGL/ES, the shared `VkDevice` for
Vulkan) and owns the **`make_*` object-creation functions** (the sole per-window
`make_framebuffer` stays on the `context` — see special cases). Every created object
(`texture_2d`, `vertex_array`, …) holds a `shared_ref<const factory>` instead of
a `shared_ref<const context>`. Every per-window `context` holds an injected
`shared_ref<const factory>` and no longer creates objects itself.

Because all windows share one factory (and the factory is tied to the shared
context), shared resources are *always* created against the shared context — the
"create shared objects with the shared context" rule is now **enforced by the
type system** instead of being a convention.

## Background / problem (current state)

Today `ruis::render::context` mixes two unrelated responsibilities:

1. **State control** — scissor, viewport, blend, depth, vsync, current-FBO.
   This is *per-window*: each window's context holds its own state and is made
   "current" in turn.
2. **Object creation** — `make_texture_2d()`, `make_vertex_array()`, … These
   return GPU objects that retain a `shared_ref<const context>` (`ctx_ref`) so
   the object cannot outlive the context that created it.

There is a separate **headless shared `context`** created by ruisapp
(`resource_loader_ruis_rendering_context`, bound to a 1×1
`shared_gl_context_native_window`) used to load shared resources (common shaders,
`renderer::objects`, fonts, …). Those objects are shared across all windows.

**The bug (issue #190):** a user can create an object (e.g. load a texture)
through a *window's* context and then try to use it in another window. The object
is pinned to the first window's context, so it is unusable/incorrect elsewhere and
pins that context (this is the root cause of the multi-window freeze/ghost bug).
The correct way is to create it via the shared context, but nothing enforces that
— the `make_*` functions are on `context`, so it is trivial to call them on the
wrong (per-window) context.

## Design overview

```
        resource_loader
        (holds the shared factory + common objects/shaders)
                 │
                 ▼
        ┌─────────────────┐
        │     factory      │  ← the shared render context
        │ (GL ctx / VkDev) │     owns the shared GPU context
        │ make_* functions │     all objects retain a ref to it
        └─────────────────┘
                 ▲  ▲  ▲          (injected shared_ref<const factory>)
                 │  │  │
        ┌────────┘  │  └────────┐
        │           │           │
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │context W1│ │context W2│ │context W3│   ← per-window contexts
   │(window+  │ │(window+  │ │(window+  │      hold a factory ref,
   │  state)  │ │  state)  │ │  state)  │      no make_* of their own
   └─────────┘ └─────────┘ └─────────┘
```

- **`factory`** = shared render context. Owns the shared GPU context. All `make_*`.
- **`context`** = per-window. Native window + state only. Holds a factory ref.
- **objects** = hold `shared_ref<const factory>` (outlive every per-window context).
- **`renderer`** = unchanged grouping: per-window `context` + common shaders +
  common objects (the common ones come from the factory).

### Why this enforces the rule
All *shareable*-object creation (`make_shaders`, `make_texture_*`, `make_vertex_*`,
`make_index_*`, `make_vertex_array`) exists **only** on the factory. A per-window
context no longer exposes those (its only remaining `make_framebuffer` is inherently
per-window), so you literally cannot create a shared object "with a window's
context" — you go through the shared factory, and the resulting object is bound to
the shared context. The `renderer::objects`/common-shaders created at startup are
created via the factory, exactly as they are today (just a different owner).

## New `ruis::render::factory` class

New files: `repos/ruis/src/ruis/render/factory.hpp` (+ `.cpp` if needed).

```cpp
namespace ruis::render {

class factory : public std::enable_shared_from_this<factory>
{
public:
    // moved from context::shaders (also resolves the pre-existing "make unique_ref" TODO)
    struct shaders {
        utki::unique_ref<const texturing_shader>          pos_tex;
        utki::unique_ref<const coloring_shader>           color_pos;
        utki::unique_ref<const coloring_shader>           color_pos_lum;
        utki::unique_ref<const shader>                    pos_clr;
        utki::unique_ref<const coloring_texturing_shader> color_pos_tex;
        utki::unique_ref<const coloring_texturing_shader> color_pos_tex_alpha;
    };

    // ---- object creation (moved verbatim from context) ----
    virtual utki::shared_ref<shaders> make_shaders() const = 0;

    virtual utki::shared_ref<texture_2d> make_texture_2d(
        rasterimage::format, rasterimage::dimensioned::dimensions_type,
        texture_2d_parameters) const = 0;
    virtual utki::shared_ref<texture_2d> make_texture_2d(
        const rasterimage::image_variant&, texture_2d_parameters) const = 0;
    virtual utki::shared_ref<texture_2d> make_texture_2d(
        rasterimage::image_variant&&, texture_2d_parameters) const = 0;

    virtual utki::shared_ref<texture_depth> make_texture_depth(
        rasterimage::dimensioned::dimensions_type) const = 0;
    virtual utki::shared_ref<texture_cube> make_texture_cube( /* 6 faces */ ) const = 0;

    virtual utki::shared_ref<vertex_buffer> make_vertex_buffer(utki::span<const r4::vector4<float>>) const = 0;
    virtual utki::shared_ref<vertex_buffer> make_vertex_buffer(utki::span<const r4::vector3<float>>) const = 0;
    virtual utki::shared_ref<vertex_buffer> make_vertex_buffer(utki::span<const r4::vector2<float>>) const = 0;
    virtual utki::shared_ref<vertex_buffer> make_vertex_buffer(utki::span<const float>) const = 0;

    virtual utki::shared_ref<index_buffer> make_index_buffer(utki::span<const uint16_t>) const = 0;
    virtual utki::shared_ref<index_buffer> make_index_buffer(utki::span<const uint32_t>) const = 0;

    virtual utki::shared_ref<vertex_array> make_vertex_array(
        std::vector<utki::shared_ref<const vertex_buffer>>,
        utki::shared_ref<const index_buffer>,
        vertex_array::mode) const = 0;

    // NOTE: make_framebuffer is deliberately NOT moved here — a frame buffer is
    // per-window (its apply() binds / sets the viewport on the per-window context
    // that renders into it), so it stays on ruis::render::context. See
    // "frame_buffer" special case.

protected:
    factory() = default;
    virtual ~factory() = default;
    factory(const factory&) = delete;
    factory& operator=(const factory&) = delete;

    // helpers for implementations to hand the factory ref to objects
    utki::shared_ref<const factory>  get_shared_ref() const;
    utki::shared_ref<factory>        get_shared_ref();
};
} // namespace
```

Notes:
- `texture_2d_parameters` (currently nested in `context`) moves to `factory` (or
  a free type in the `ruis::render` namespace) so the factory is self-contained.
- The factory is **non-movable / non-copyable** (like `context`).
- `shaders` moves out of `context` into `factory`; update the alias used by
  `renderer::common_shaders` (see below).

## `ruis::render::context` changes

File: `repos/ruis/src/ruis/render/context.hpp` (+ `.cpp`).

- **Remove** the shareable-object `make_*` virtual functions (all except
  `make_framebuffer`) and the nested `shaders` struct.
- **Add** an injected factory member:
  ```cpp
  const utki::shared_ref<const ruis::render::factory> factory;
  context(
      utki::shared_ref<ruis::render::native_window>, //
      parameters, //
      utki::shared_ref<const ruis::render::factory>  // ← new
  );
  const ruis::render::factory& factory() const noexcept { return *this->factory; }
  ```
- **Keep** all state-control functions unchanged (scissor, viewport, blend, depth,
  vsync, current-FBO, `apply()`, `current()`, `is_current()`), and **keep
  `make_framebuffer`** (it stays on the context — see special cases).
- **`get_shared_ref()` / `enable_shared_from_this` stay on the context, but the only
  remaining use is `make_framebuffer`**, which hands the non-const context ref to the
  created `frame_buffer`. Once every shareable-object `make_*` moves to the factory,
  nothing else calls `context::get_shared_ref()` — the "current context" machinery
  (`cur_context_stack` / `current()`) uses raw `const context*`, not shared refs.

## Object class changes (`ctx_ref` → factory ref)

Each of these changes its stored context ref from
`shared_ref<const context>` to `shared_ref<const factory>`
(and `frame_buffer` is a special case, below):

| File | Member | New type |
|---|---|---|
| `render/texture_2d.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/texture_depth.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/texture_stencil.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/texture_cube.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/vertex_buffer.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/index_buffer.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/vertex_array.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/shaders/shader.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/shaders/coloring_shader.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/shaders/texturing_shader.hpp` | `rendering_context` | `shared_ref<const factory>` |
| `render/shaders/coloring_texturing_shader.hpp` | `rendering_context` | `shared_ref<const factory>` |

- The protected constructor parameter changes from
  `shared_ref<const context>` to `shared_ref<const factory>`.
- Forward-declare `class factory;` in each header (replacing `class context;`).
- **Rename** the member from `rendering_context` to `factory` for clarity (optional
  but recommended).
- The four **shader base classes** (`shader`, `coloring_shader`, `texturing_shader`,
  `coloring_texturing_shader`) are created by `make_shaders` (which also moves to the
  factory), so their `rendering_context` pin becomes a factory ref too. The concrete
  per-renderer shaders (`shader_pos_tex`, `shader_color`, …) only forward the ref to
  their base, so their constructor parameter type changes accordingly (in each
  renderer repo).
- `renderer.hpp` also references the context; see below.

Because objects now hold the factory (which is the shared context and outlives all
windows), an object created for one window is safely usable in any other window —
exactly the desired semantics.

## `ruis::render::renderer` and `renderer::objects`

File: `repos/ruis/src/ruis/render/renderer.hpp` (+ `.cpp`).

- `renderer` keeps grouping: per-window `context` + common shaders + common
  objects (unchanged conceptually).
- `renderer::objects` constructor changes from `const context&` to the factory:
  ```cpp
  struct objects {
      objects(const ruis::render::factory& factory); // was: const context&
      // all make_* calls now go through `factory`
  };
  ```
- `renderer::common_shaders` type changes from
  `shared_ref<const context::shaders>` to `shared_ref<const factory::shaders>`
  (the `shaders` struct moved to the factory).
- Add a convenience accessor so call sites can reach the factory without a
  window:
  ```cpp
  const ruis::render::factory& factory() const noexcept; // rendering_context->factory()
  ```
  (or expose it via `common_*` provenance). Callers that only need object
  creation can use `renderer.factory()`.

## `ruis::resource_loader` changes

File: `repos/ruis/src/ruis/resource_loader.hpp` (+ `.cpp`).

- Member `const shared_ref<const context> rendering_context` becomes
  `const shared_ref<const factory> factory`.
- Constructor parameter `shared_ref<const context>` → `shared_ref<const factory>`.
- `common_rendering_objects` is still created via the factory (by ruisapp) and
  stored unchanged.
- Public accessors: code that reads
  `context.get().loader().rendering_context` (used by the VAO/paint code to get
  the shared context for object creation) now reads
  `context.get().loader().factory` (and calls `factory->make_*` on it).

## Renderer implementations

Each renderer moves its `make_*` overrides from `context` into a new `<api>::factory`
and gives its `context` a factory.

### ruis-render-opengl / ruis-render-opengles
- New `ruis::render::opengl::factory` (and `opengles::factory`) owning the **shared
  GL context** created from the headless `shared_gl_context_native_window`.
  Its `make_*` create GL objects in that shared context and wrap them, passing
  `this->get_shared_ref()` (the factory ref) as the object's `ctx_ref`.
- `ruis::render::opengl::context` constructor becomes
  `(native_window, shared_ref<const factory>)`. It no longer owns GL object
  creation; it makes the **shared GL context current on its window's surface** for
  state/drawing. GLX context sharing is what makes factory-created objects visible
  in each window (already true today).
- Move the `make_*` bodies out of `context.cpp` into `factory.cpp` (the `gl` calls
  are unchanged; only the object `ctx_ref` changes from the context ref to the
  factory ref).

### ruis-render-vulkan
- New `ruis::render::vulkan::factory` owning the shared `vulkan_device`
  (`VkInstance` + `VkDevice`). Its `make_*` create GPU resources on the shared
  device and wrap them with the factory ref. (Vulkan has no "current context", so
  no surface is needed — matches the existing headless-context behavior.)
- `ruis::render::vulkan::context` constructor becomes
  `(native_window, surface_provider, shared_ref<const factory>)`. It uses the
  factory's `vulkan_device` for swapchain/framebuffer/draw work; it no longer owns
  a separate device.
- Move the `make_*` bodies into `factory.cpp`.

### ruis-render-null
- A no-op `null::factory` whose `make_*` return empty/trivial objects (or throw),
  mirroring the existing `null::context`. It is required because the null renderer
  fully implements the `context` interface (so it has the same `make_*` overrides to
  move).

> The factory is constructed **once** by ruisapp and shared by reference into every
> context, so there is a single shared GPU context/device per process.

## Shared context / factory creation (ruisapp glue)

Files (per platform): `ruisapp/src/ruisapp/glue/linux/{xorg/wayland/...}`,
`ios`, `android`, `sdl`, `windows`, `macosx` glue.

Before (Xorg example):
```cpp
resource_loader_ruis_rendering_context(
    utki::make_shared<ruis::render::vulkan::context>(
        this->shared_gl_context_native_window,
        this->resource_loader_surface_provider)),
common_shaders( this->resource_loader_ruis_rendering_context.get().make_shaders() ),
common_render_objects(
    utki::make_shared<ruis::render::renderer::objects>(
        this->resource_loader_ruis_rendering_context)),
ruis_resource_loader(
    utki::make_shared<ruis::resource_loader>(
        this->resource_loader_ruis_rendering_context,
        this->common_render_objects)),
```
After:
```cpp
render_factory(
    utki::make_shared<ruis::render::vulkan::factory>(
        this->shared_gl_context_native_window,
        this->resource_loader_surface_provider)),      // ← factory is the shared ctx
common_shaders( this->render_factory->make_shaders() ),
common_render_objects(
    utki::make_shared<ruis::render::renderer::objects>(*this->render_factory)),
ruis_resource_loader(
    utki::make_shared<ruis::resource_loader>(
        this->render_factory,   // shared_ref<const factory>
        this->common_render_objects)),
```
- Per-window context creation in each `make_window()` now passes the factory:
  `make_shared<vulkan::context>(native_window, surface_provider, this->render_factory)`.
- The member `resource_loader_ruis_rendering_context`
  (`shared_ref<render::context>`) becomes `render_factory`
  (`shared_ref<const render::factory>`).

## Call-site migration

- ~42 `make_*` call sites in `ruis` (`renderer::objects`, paint/VAO code, font
  code, `widget` caching, …) change from `ctx.make_*` to `ctx.factory().make_*`
  (or, where the shared factory is already in hand via the loader,
  `loader().factory->make_*`).
- The paint/VAO code merged in #191 used
  `context.get().loader().rendering_context` for texture creation; that becomes
  `context.get().loader().factory` (and the stored member type becomes
  `shared_ref<const factory>`).
- Tests and apps under `ruis/tests` and `ruisapp/tests` that construct contexts or
  call `make_*` are updated to the new signatures.

## Special cases

### `frame_buffer` (non-const context)
`frame_buffer::apply()` uses a **non-const** `shared_ref<context>`
(`this->rendering_context.get()`) to call `set_viewport()` and checks
`is_current()`. A frame buffer is fundamentally **per-window** (it is the render
target bound while a specific window renders), so it should **not** be reduced to
a factory ref.

**Decision — Option A:** `make_framebuffer` stays on the per-window `context` and is
**not** moved to the factory. A frame buffer *cannot* be shared between contexts: in
OpenGL an FBO is a per-context object, and `frame_buffer::apply()` binds it and sets
the viewport on the specific per-window context that renders into it. So
`frame_buffer` keeps its non-const `shared_ref<context>` (the one context that owns
it), while the shareable `make_*` (shaders, textures, buffers, vertex arrays) move to
the factory. This is the minimal, semantically-correct change.

(Rejected: B — move `make_framebuffer` to the factory but take the target
`context&` as an argument; C — make `apply()` use `context::current()`. Both add
complexity for no benefit, since the FBO is inherently per-window.)

### "current context" during resource loading
The factory needs **no `with_current(fn)` machinery**. With OpenGL/ES a rendering
context is always current at the moment a factory `make_*` runs, and the factory's GL
context is **shared** with every other GL context in the process — so the `gl*` calls
inside `make_*` simply operate on whatever GL context is current (the headless
factory context at startup, or a window's context during a later cache fill). No
extra "make the factory context current" step is required. (Vulkan has no "current
context" at all, so this is a non-issue there.)

### `context::shaders` → `factory::shaders`
The `shaders` struct and `make_shaders()` move to the factory. Update every
`context::shaders` reference (notably `renderer::common_shaders`).

## Migration steps (ordering)

This is a cross-cutting change (ruis core + all 4 renderers + ruisapp glue + tests), so
do it on a single branch, grouped into reviewable commits:

1. **ruis core — add `factory`:** new `factory.hpp/.cpp`; move `shaders` +
   `texture_2d_parameters` + the shareable-object `make_*` declarations (NOT
   `make_framebuffer`) out of `context` into `factory`; give `context` the injected
   factory member + `factory()` accessor and remove those `make_*` (keep
   `make_framebuffer`). (Build is red until steps 2–4.)
2. **ruis core — objects + renderer + loader:** switch the 7 object classes **and the
   4 shader base classes** to a factory `ctx_ref`; change `renderer::objects` ctor +
   `common_shaders` type (`context::shaders` → `factory::shaders`); change
   `resource_loader` member/ctor.
3. **ruis core — call sites:** update the ~42 `make_*` call sites (and the
   #191 paint/VAO code) to route through the factory.
4. **Renderers:** implement `<api>::factory` (opengl, opengles, vulkan, and the
   null/test renderer) owning the shared GPU context/device (the null factory is a
   no-op); move `make_*` bodies in; give each `<api>::context` the factory.
   (Vulkan: factory owns `vulkan_device`.)
5. **ruisapp glue (all platforms):** create the factory once; pass it into every
   per-window context and the resource loader; rename the shared-context member to
   `render_factory`.
6. **Tests/apps:** update `ruis/tests`, `ruisapp/tests`, and any sample that builds
   a context or calls `make_*`.
7. **`cod` + other consumers:** adapt downstream `make_*` / VAO usage if affected.

After each renderer is updated its target should build; the whole `all` target is
green only after step 5.

## Verification

- Full monorepo `all` build (ruis + all renderers + all ruisapp variants + cod).
- ruis unit tests (incl. the paint test with rounded rects / ellipses / paths).
- Format clean (clang-format) + lint (clang-tidy).
- **Runtime (the point of the issue):**
  - Xorg Vulkan: open several windows, close in mixed order — no ghost windows, no
    freeze (regression check for the multi-window bug this design eliminates).
  - Wayland Vulkan: same — no crash, clean teardown.
  - Rendering matches the pre-refactor output (pixel-diff vs OpenGL baseline).
- **Enforcement is by construction:** every *shareable* object (shaders, textures,
  vertex/index buffers, vertex arrays) can only be created through the factory — the
  per-window `context` no longer exposes those `make_*` (its sole remaining
  `make_framebuffer` is inherently per-window). So the "create shared objects with
  the shared context" rule is enforced by the type system itself; no separate
  audit/grep step is needed.

---

## Status (updated 2026-11-22)

**MERGED to main:**
- ruis #192, #193 ✅
- ruis-render-null #3 ✅
- ruis-render-opengl #4 ✅
- ruis-render-opengles #5 ✅
- ruis-render-vulkan #2 ✅
- ruisapp #29 ✅

**Still open (waiting for ruisapp release in vcpkg):**
| repo | PR |
|---|---|
| carcockpit | #8 |
| cod | #1 |
| ruis-sdl-example | #2 |
| bedsidemon | #6 |

**CI status / cross-repo dependency chain:**
This is a cross-repo API change (the `ruis::render::factory` class is new in ruis
core, and every ruisapp/renderer/app glue depends on it). The CI has a release-order
dependency:

1. **ruis #192** — lint FIXED (made factory destructor `public virtual` to satisfy
   `cppcoreguidelines-virtual-class-destructor`, matching `context`). The
   coverage/sanitizer/linux jobs are RED because the CI checks out the
   `tests/harness/modules` submodules at their **main branch tips** (the
   `myci-actions/checkout` default is `submodules: remote_recursive`), and main
   ruisapp/renderers don't have the factory yet. → merge ruis #192, **release ruis**.
2. **renderers** (null/opengl/opengles/vulkan) — RED because they install the
   *released* ruis (0.6.27, no factory). → after ruis release, their CI goes green.
   Merge + release renderers.
3. **ruisapp #29** — RED until new ruis + renderers are released. Then green.
   Merge + release ruisapp.
4. After ruisapp+renderers are on **main**, the ruis CI (harness submodules at main)
   goes green.
5. **apps** (carcockpit/cod/ruis-sdl-example) — RED until new ruis is released.

No version bumps needed: the debian `libruis-dev (>= 0.6.27)` constraint will pick
up the new ruis automatically once it's released.

---

## Implementation progress

All implementation work is done; the changes are pushed as `ren_factory` branches
and opened as PRs. Every PR is currently **OPEN**.

### PRs

| # | repo | PR | head | URL |
|---|------|----|------|-----|
| 1 | ruis (core) | #192 | f0a2fecb | https://github.com/cppfw/ruis/pull/192 |
| 2 | ruis-render-null | #3 | e4febb4 | https://github.com/cppfw/ruis-render-null/pull/3 |
| 3 | ruis-render-opengl | #4 | c5de074 | https://github.com/cppfw/ruis-render-opengl/pull/4 |
| 4 | ruis-render-opengles | #5 | f6d6518 | https://github.com/cppfw/ruis-render-opengles/pull/5 |
| 5 | ruis-render-vulkan | #2 | 58c9ef4 | https://github.com/cppfw/ruis-render-vulkan/pull/2 |
| 6 | ruisapp | #29 | 594877b | https://github.com/cppfw/ruisapp/pull/29 |
| 7 | carcockpit | #8 | 5d2de4a | https://github.com/gagistech/carcockpit/pull/8 |
| 8 | cod | #1 | 7e6f616 | https://github.com/igagis/cod/pull/1 |
| 9 | ruis-sdl-example | #2 | 25b9e06 | https://github.com/cppfw/ruis-sdl-example/pull/2 |
| 10 | bedsidemon | #6 | 7d20306 | https://github.com/gagistech/bedsidemon/pull/6 |

### Checklist

- [x] Plan written (issue #190)
- [x] `ren_factory` branches created in all 9 repos
- [x] `ruis` core: `factory` class + `context`/`renderer`/`resource_loader`/`objects` rewired (phase A)
- [x] `ruis-render-null` factory (phase B)
- [x] `ruis-render-opengl` factory (phase B)
- [x] `ruis-render-opengles` factory (phase B)
- [x] `ruis-render-vulkan` factory (phase B)
- [x] `ruisapp` glue: linux xorg/wayland, sdl, ios, android, windows, macos (phase C)
- [x] `ruis` tests: dummy_context, style, paint, cube (phase D)
- [x] apps: carcockpit, cod (phase E)
- [x] `ruis-sdl-example` (phase E)
- [x] Full monorepo builds clean, all tests pass, format clean
- [x] All 10 PRs created and pushed
- [x] ruis #192: addressed all 8 inline review comments (see below)
- [x] ruis #192: round-2 review fixes — `fac()` accessor, `rendering_context`→`factory` renames, CI `submodules: true` (see below)
- [x] ruis #192: round-4 review fixes — `this->ctx().ren().ctx().fac()` shortcuts, drop the retained native window from the GL factories (see below)
- [x] ruis #192: fixed CI to check out harness submodules at their pinned commits (not main tips)
- [ ] Merge + release ruis (unblocks renderers)
- [ ] Merge + release renderers (unblocks ruisapp + ruis CI harness)
- [ ] Merge + release ruisapp (unblocks apps)
- [ ] Merge apps

### ruis #192 review comments (addressed 2026-11-19)

Commit `675f3dfd` addresses all 8 inline review comments:

1. `texture_font.hxx` — renamed `rendering_context` member → `factory`.
2. `texture_font.hxx` — renamed the ctor parameter `rendering_context` → `factory`.
3. `texture_font_face.cpp` — renamed the ctor parameter → `factory`.
4. `texture_font_face.hxx` — renamed the `rendering_context` member → `factory`.
5. `texture_font_face.hxx` — renamed the ctor parameter → `factory`.
6. `ellipse_vao.hpp` — removed the stale “use the shared resource-loader factory” / “must outlive this VAO” doc comment (the factory is shared between all contexts; the retained `shared_ref` guarantees its lifetime). Same fix applied to `rectangle_vao.hpp`.
7. `ellipse_vao.hpp` — removed the “must outlive this VAO” note from the ctor doc.
8. `path_vao` — refactored to match `rectangle_vao`/`ellipse_vao`: retains only the shared `factory` (no `renderer`/`context`); ctor takes `(factory, objects)`; `render()` takes the `renderer` as a parameter. Call sites updated (ruis `paint`/`wire_area` tests, and the `bedsidemon` app — a 10th repo added for this reason).

### ruis #192 round-2 review fixes (addressed 2026-11-20)

ruis commit `e8fce74f` (+ vulkan `58c9ef4`, ruisapp `594877b`, carcockpit `5d2de4a`):

1. **`context`: public `factory` member + `fac()` shorthand.** The render factory
   stays a **public** member of the context (as before). A new `const
   ruis::render::factory& fac() const` shorthand returns a reference to it, for the
   common `context.fac().make_*()` call sites. (The shorthand is named `fac()` — not
   `factory()` — because `factory` is also the *type* name `ruis::render::factory`,
   and a member/method named `factory` would trigger `-Wchanges-meaning` and hide the
   type. The return type is qualified for the same reason.)
2. **`rendering_context` → `factory` renames.** The shareable object/shader base
   classes (`index_buffer`, `texture_*`, `vertex_*`, `shaders/*`) and the `res/*`
   helpers still used the stale name `rendering_context`; renamed to `factory`
   (these members are private, so the name is low-stakes). All `.factory()` call
   sites on a context updated to `.fac()` (ruis `widget.cpp`, `book`/`app1` tests,
   ruisapp test app, carcockpit `scene_view`/`scene_renderer`).
3. **Vulkan: qualify the type in downcasts.** The base-class `factory` *data
   member* hides the *type* `ruis::render::factory` in the derived (concrete
   buffer/texture) class scope, breaking the `static_cast<const factory&>`
   downcasts. Fixed by qualifying the type to `ruis::render::vulkan::factory`
   (the concrete factory that owns `device`/`all_textures`/`one_shot`).
4. **CI: `submodules: true`.** The ruis submodules have no nested submodules, so
   the checkout uses `submodules: true` (simpler than `recursive`).

### CI fix (ruis #192)

Commit `6230360f` changes the ruis CI workflow so the `tests/harness/modules`
and `libraries` submodules are checked out at their **pinned gitlink commits**
(`submodules: true`) instead of their `main` branch tips
(`myci-actions/checkout@main` defaults to `submodules: remote_recursive`).
Combined with the bumped submodule pins (→ the `ren_factory` commits), this lets
the ruis CI build the `ren_factory` renderers/ruisapp directly, so the ruis
linux/coverage/sanitizer jobs can go green **without** waiting for a ruis release.
(The renderer/app PRs still need a released ruis with the `factory`, per the
release-order chain above.)

### bedsidemon (10th repo)

`apps/bedsidemon` is a standalone git repo auto-included in the monorepo `all`
build (via the apps glob). It uses `ruis::paint::path_vao` (old renderer-retaining
API), so the `path_vao` refactor (review comment 8) required a matching update
there. Added as repo #10 / PR #6 on a `ren_factory` branch.

### ruis #192 round-3 review fixes (addressed 2026-11-20, ruis `d01a0f6b`)

Five more comments, all addressed + replied (reply ids 4629631032, 4629631494,
4629631883, 4629632218, 4629632608):

1. **`rectangle_vao.cpp`**: renamed the factory-typed `ctx` params/vars → `factory`
   (make_quad_vao, make_corner_vaos, rounded_corners_texture). `r.ctx()` (a method,
   a real context) left as-is.
2. **`context::fac()`**: dropped the explicit `.get()` — `shared_ref` auto-casts to a
   const reference via its `operator object_type&()`. Same simplification in the new
   `resource_loader::fac()`.
3. **`resource_loader`**: added a `fac()` shorthand; used it in the `res/*` loaders
   (texture_cube, image, texture_2d) instead of `loader.factory.get()`.
4. **`widget` / `gradient` / `texture_font`**: use the renderer's `ctx()` (const +
   non-const overloads) instead of `.rendering_context.get()`.
5. Answered where the OpenGL factory makes its headless context current: the
   `factory` ctor's `gl_version` initializer (`opengl/factory.cpp:137`,
   `this->bind(this->native_window.get())`).

### ruis #192 round-4 review fixes (addressed 2026-11-20)

Four more comments, all addressed + replied (reply ids 4630084614, 4630085001,
4630086875):

1. **Shortcut chains**: replaced the verbose `context.get().renderer.get().ctx().fac()`
   chains with `this->ctx().ren().ctx().fac()` in `tests/app1/src/cube_widget.cpp`,
   `tests/book/src/cube_page.cpp`, and shortened the analogous chains in
   `widget/widget.cpp` to `r.ctx()` / `this->ctx().ren().ctx()`. ruis commit
   `2c59f864`.
2. **Native window retention** (factory design question, `factory.hpp:81`):
   the *concrete* renderer factory retains the `native_window` — it holds the actual
   shared (headless) GL context and must keep it alive for all `make_*` calls — while
   the *abstract* `ruis::render::factory` does not. Initially the retention was removed
   (opengl `c25d323` / opengles `b63a357`) per an early comment, then restored with an
   explanatory comment (opengl `c5de074` / opengles `f6d6518`) after the reviewer
   clarified that the concrete factory owns the shared context.

### ruis #192 merged + Vulkan renderer PR #2 review fixes (addressed 2026-11-19)

ruis #192 (the factory extraction) was **merged** to `main` (`c176516c`); the
`ren_factory` branch was removed locally and remotely.

The **ruis-render-vulkan PR #2** then got 7 review comments (ids 4630750338,
4630768598, 4630781643, 4630823399, 4630864360, 4630900824, 4630921044), all
addressed + replied (reply ids 4632069781, 4632072540, 4632074662, 4632076891,
4632078697, 4632081016, 4632083101):

1. **`shader_color.hpp:34`**: renamed the ctor param `rendering_context` → `factory`
   in all Vulkan shader + object classes.
2. **shared_ref passing**: pass the `shared_ref<const factory>` **by value** and
   `std::move` into the base class (not by const-ref).
3. **`shader_color_pos_lum.hpp:40`**: renamed to `factory` in all sibling shaders
   (color_pos_tex, color_pos_tex_alpha, pos_tex, pos_clr, color).
4. **redundant `ctx_ref` (shaders)**: removed from all 6 shader classes — the base
   shader classes now retain `factory` as **protected** (ruis #193), so the derived
   classes access it directly.
5. **`context.hpp:196`**: renamed `vu_factory` → `factory` in the context.
6. **redundant `ctx_ref` (index_buffer)**: made the base's `factory` member
   **protected** (ruis #193) and removed `ctx_ref` from `index_buffer` (and the other
   GPU objects: texture_2d, vertex_buffer, texture_depth).
7. **const_cast (texture_2d.cpp:251)**: the `const_cast` was needed because the
   texture ctor/dtor mutated the factory's `all_textures` (a public member). Made
   `all_textures` **private mutable** + added const `register_texture()` /
   `unregister_texture()` accessors, so the `const_cast` is gone and the factory
   stays const. Also removed the redundant `ctx_ref` from `frame_buffer` (uses the
   base's already-protected `rendering_context`).

**Commits:**
- ruis core: `ren_fac_prot` branch, commit `ee43a5b3` → **new PR #193**
  (https://github.com/cppfw/ruis/pull/193) — the protected-`factory` base-class
  change that the Vulkan PR depends on.
- ruis-render-vulkan: `ren_factory` branch, commit `62c9467` (pushed, updates PR #2).

**Status:** ruis #193 **MERGED** to `main` (`7662d763`); the `ren_fac_prot` branch
was removed locally and remotely and ruis is back on the latest `main`.
Vulkan PR #2 is still OPEN (waiting for a new ruis release with the protected
`factory` member, then its CI goes green).
Build clean, all tests pass, lint clean, formatted.

---

## Follow-up: Vulkan PR #2 comment + ruisapp `vulkan` rebase (done)

### ruis-render-vulkan PR #2 — comment 4632150852 (surface_provider / native_window)
The reviewer asked: *"what is surface provider? isn't surface a part of a window?
looks like the vulkan renderer doesn't use the passed in native_window, so why is
the argument here? Who creates the surface for window contexts? is it native
window?"*

**Fix:** the `native_window` ctor param on `vulkan::factory` was dead weight (the
factory only reads the GPU handles off the surface provider). Removed it.
- commit `678c8a5` on `ren_factory` (pushed, updates PR #2).
- factory ctor is now `factory(const shared_ref<const surface_provider>&)`.

**Reply posted** (id 4633316540) explaining the layering:
- `vulkan_device` owns VkInstance/VkPhysicalDevice/VkDevice/VkQueue (one per app,
  created by the glue). `surface_provider` = `vulkan_device&` + optional VkSurfaceKHR.
- Headless surface provider (VK_NULL_HANDLE) → builds the shared **factory**
  (surface-less; only needs the GPU handles for texture/buffer creation).
- Per-window surface provider (real VkSurfaceKHR) → passed to the per-window
  `vulkan::context` ctor.
- The **glue** (ruisapp) creates each window's VkSurfaceKHR and the surface
  providers — not the factory and not the native_window.

All 8 reviewer comments on PR #2 are now addressed + replied.

### ruisapp — rebase `vulkan` onto `ren_factory` + PR #28
The old `vulkan` branch (16 pre-factory commits, based on `main`) was ported onto
`ren_factory` and rewritten against the factory API, as a single commit.

- **Strategy:** the 16 intermediate commits don't compile in isolation (they use
  the pre-factory 1–2-arg context ctors), so a commit-by-commit rebase was not
  viable. Instead: created a branch from `ren_factory`, checked out all
  vulkan-branch files wholesale, then adapted the 4 files that overlap the factory
  change (xorg/glue.cxx, wayland/application.hxx, wayland/application.cxx,
  xorg/window.hxx) to the factory API.
- **Factory adaptation:**
  - xorg: one shared `vulkan::factory` (headless surface provider); per-window
    `win_surface_provider` (Xlib surface) + `vulkan_factory_ref` downcast →
    `vulkan::context(native_window, surface_provider, vulkan_factory_ref)`.
  - wayland: `vulkan_device` + headless `vulkan_surface_provider` members;
    per-window `vulkan::context(win, wl_surface_provider, vulkan_factory_ref)`.
  - GL/GLES per-window context ctors now pass `this->render_factory` (2-arg).
  - Added `ruis/render/{opengl,opengles}/factory.hpp` includes (the base
    `context.hpp` does not pull in the concrete factory headers).
  - Restored `utki::assert(false, SL);` in xorg/window.hxx (the old branch had a
    deprecated `ASSERT(false)` with no semicolon — latent GL-only breakage).
- **CMake:** added `ruisapp_build_vulkan_variant` gate; `ruisapp-vulkan-xorg` /
  `ruisapp-vulkan-wayland` libraries + test apps, built only when
  `ruis-render-vulkan` is available; vulkan targets added to the export set.
- Removed an unused `#include <cstdio>` (leftover debug include).

- commit `2793b4d` "Integrate the Vulkan renderer" on `vulkan` (force-pushed,
  replaces the old `a25429e`).
- **PR #28** (https://github.com/cppfw/ruisapp/pull/28) base changed
  `main` → **`ren_factory`** (the vulkan glue depends on the factory API, which is
  only on `ren_factory`); body updated to describe the factory-based approach.

**Verified:** all 6 ruisapp renderer variants + all test-app targets build, full
`all` target builds clean (0 errors), all tests pass (exit 0), format clean,
clang-tidy clean on the vulkan variants.

**CI note (expected):** ruisapp PR #28 cannot go green in its own CI until
`ruis-render-vulkan` is **released** with the 1-arg `vulkan::factory` ctor (PR #2),
because ruisapp's standalone CI fetches ruis-render-vulkan from the published
vcpkg package, not from the monorepo. This is the same release-ordering gate as
the other renderer/app PRs (ruis → ruis-render-* → ruisapp → apps).
