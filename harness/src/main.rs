// em-harness — headless conviction harness for the EcoManager FAF mod.
//
// Loads the REAL mod files (unmodified, from the repo) into a vendored Lua 5.1,
// shimming the FA engine surface (Class, import, categories, units, economy).
// One `cargo run` replaces one SupCom launch for the entire name-integrity /
// nil-index bug class, plus behavioral regressions on scripted economies.
//
// FA-dialect preprocessing (parse-time only, files on disk untouched):
//   `for k,v in <expr> do`  ->  `for k,v in pairs(<expr>) do`   (LuaPlus table iteration)
//   `math.mod` is aliased in the shim (Lua 5.0 name).

use mlua::{Lua, MultiValue, Value};
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};

fn repo_root() -> PathBuf {
    // harness/ sits inside the repo
    let exe_dir = std::env::current_dir().expect("cwd");
    for cand in [exe_dir.clone(), exe_dir.join(".."), exe_dir.join("../..")] {
        if cand.join("mod_info.lua").exists() {
            return cand.canonicalize().unwrap();
        }
    }
    panic!("run from repo root or harness/ (mod_info.lua not found)");
}

/// LuaPlus lets you write `for k,v in some_table do`. Lua 5.1 needs pairs().
/// Wrap any generic-for iterator expression that isn't already a call to
/// pairs/ipairs/next in pairs(...).
fn preprocess(src: &str) -> String {
    let re = Regex::new(r"(?m)(\bfor\s+[A-Za-z_][A-Za-z0-9_]*\s*(?:,\s*[A-Za-z_][A-Za-z0-9_]*)?\s+in\s+)(.+?)(\s+do\b)").unwrap();
    re.replace_all(src, |caps: &regex::Captures| {
        let head = &caps[1];
        let expr = caps[2].trim();
        let tail = &caps[3];
        if expr.starts_with("pairs")
            || expr.starts_with("ipairs")
            || expr.starts_with("next")
        {
            format!("{}{}{}", head, expr, tail)
        } else {
            format!("{}pairs({}){}", head, expr, tail)
        }
    })
    .to_string()
}

fn load_file(lua: &Lua, root: &Path, rel: &str) -> mlua::Result<()> {
    let path = root.join(rel);
    let src = fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("read {}: {}", path.display(), e));
    let pre = preprocess(&src);
    lua.load(&pre).set_name(rel).exec()
}

fn main() {
    let root = repo_root();
    let lua = Lua::new();

    // ---- shim: FA engine surface ----------------------------------------
    let shim_src = fs::read_to_string(root.join("harness/shim.lua")).expect("shim.lua");
    lua.load(&preprocess(&shim_src)).set_name("shim.lua").exec()
        .unwrap_or_else(|e| panic!("shim failed: {}", e));

    // import(): resolve /mods/EM/* against repo root, everything else against
    // the shim's virtual module registry; cache like the engine does.
    {
        let root2 = root.clone();
        let globals = lua.globals();
        let import_cache: mlua::Table = lua.create_table().unwrap();
        globals.set("__import_cache", import_cache).unwrap();
        let import_fn = lua
            .create_function(move |lua, path: String| {
                let cache: mlua::Table = lua.globals().get("__import_cache")?;
                if let Ok(Value::Table(t)) = cache.get::<Value>(path.clone()) {
                    return Ok(Value::Table(t));
                }
                // virtual modules first (engine + /mods/common)
                let virtuals: mlua::Table = lua.globals().get("__virtual_modules")?;
                if let Ok(Value::Table(t)) = virtuals.get::<Value>(path.clone()) {
                    cache.set(path.clone(), &t)?;
                    return Ok(Value::Table(t));
                }
                let rel = path
                    .strip_prefix("/mods/EM/")
                    .unwrap_or_else(|| panic!("import of unshimmed path: {}", path));
                let file = root2.join(rel);
                let src = fs::read_to_string(&file)
                    .unwrap_or_else(|e| panic!("import {}: {}", file.display(), e));
                let pre = preprocess(&src);
                // FA modules execute in a fresh env whose globals become the module table,
                // with fallthrough to real globals.
                let module: mlua::Table = lua.create_table()?;
                let meta: mlua::Table = lua.create_table()?;
                meta.set("__index", lua.globals())?;
                module.set_metatable(Some(meta));
                cache.set(path.clone(), &module)?; // pre-set: tolerate import cycles
                let chunk = lua.load(&pre).set_name(rel).set_environment(module.clone());
                chunk.exec()?;
                Ok(Value::Table(module))
            })
            .unwrap();
        globals.set("import", import_fn).unwrap();
    }

    // ---- phase 1: parse-conviction — every mod lua file must load --------
    let mut files: Vec<PathBuf> = vec![];
    for dir in ["throttler", "modules", "controlPannel"] {
        for entry in fs::read_dir(root.join(dir)).unwrap() {
            let p = entry.unwrap().path();
            if p.extension().map(|e| e == "lua").unwrap_or(false) {
                files.push(p);
            }
        }
    }
    files.sort();
    let mut parse_fail = 0;
    for f in &files {
        let rel = f.strip_prefix(&root).unwrap().to_string_lossy().to_string();
        let src = fs::read_to_string(f).unwrap();
        let pre = preprocess(&src);
        match lua.load(&pre).set_name(&rel).into_function() {
            Ok(_) => println!("PARSE OK   {}", rel),
            Err(e) => {
                parse_fail += 1;
                println!("PARSE FAIL {} — {}", rel, e);
            }
        }
    }

    // ---- phase 2: scenario runs — real init + ticks on scripted economies
    let scen_src = fs::read_to_string(root.join("harness/scenario.lua")).expect("scenario.lua");
    let result: mlua::Result<MultiValue> = lua
        .load(&preprocess(&scen_src))
        .set_name("scenario.lua")
        .eval();
    let _ = load_file; // keep helper linked for future direct loads

    match result {
        Ok(vals) => {
            let mut failed = 0;
            for v in vals.iter() {
                if let Value::Integer(n) = v {
                    failed = *n;
                }
            }
            if parse_fail > 0 || failed > 0 {
                println!("\nHARNESS: FAIL (parse {}, scenario {})", parse_fail, failed);
                std::process::exit(1);
            }
            println!("\nHARNESS: ALL GREEN");
        }
        Err(e) => {
            println!("\nSCENARIO CRASH: {}\nHARNESS: FAIL", e);
            std::process::exit(1);
        }
    }
}
