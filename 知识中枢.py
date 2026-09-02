# -*- coding: utf-8 -*-
r"""
知识中枢管理器 v2 — 便携版（路径解绑，可随驾驶舱插件部署到任意机器）
=====================================================================
模型：图书馆目录 vs 书库
  - 已注入主系统的技能 → 中文指针卡（不搬运，不破坏主系统）
  - 待整理内容 → 物理收录进中枢暂存，promote 一条命令注入主系统
  - 大文件（教学视频等）→ 指针卡记录原路径，不复制

命令：
  ingest <路径> [--to 类目/子类] [--move]     收录文件/文件夹（自动分类+中文名+去重）
  scan [--tidy]                               处理 00_收件箱
  harvest [--roots F:\ D:\] [--max-min 8]     全盘收割技能/提示词/教程/书籍
  promote <序号|关键词>                        把"待整理"技能注入主系统技能目录
  report / dedupe [--delete]                  统计 / 查重
配置：
  本目录 config.json（可选）：inject_target / harvest_roots / exclude_dirs / media_keywords / size_copy_limit_mb
"""
import sys, io, json, hashlib, shutil, re, argparse, difflib, time, os
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

HUB = Path(__file__).resolve().parent          # 中枢根 = 脚本所在目录（便携）
CFG_PATH = HUB / "config.json"
INDEX = HUB / "_索引" / "knowledge_index.json"
NEAR_DUPE_RATIO = 0.92

DEFAULT_CFG = {
    "inject_target": str(Path.home() / ".agents" / "skills"),
    "harvest_roots": ["F:\\", "D:\\"],
    "size_copy_limit_mb": 20,
    "harvest_max_minutes": 8,
    "exclude_dirs": ["$RECYCLE.BIN", "System Volume Information", "Config.Msi", "AppData",
                     "Windows", "Program Files", "Program Files (x86)", "ProgramData",
                     "node_modules", ".git", ".pnpm-store", "pnpm-store", "__pycache__",
                     "python312", "Python314", "Python313", "venv", ".venv", "site-packages",
                     "JianyingPro Materials", "JianyingPro Drafts", "剪映工程文件",
                     "迅雷下载", "BaiduNetdisk", "WPSDrive", "Package Cache", "NovelAI",
                     "DumpStack.log.tmp", "软件打包", "models", "models--", ".cache",
                     "DeskBox", "Everything", "QuickLook", "TagStudio", "Lively Wallpaper"],
    "exclude_ext": [".exe", ".dll", ".pak", ".bin", ".dat", ".apk", ".zip", ".rar", ".7z",
                    ".iso", ".msi", ".msixbundle", ".tar", ".gz", ".tgz", ".woff", ".woff2",
                    ".ttf", ".otf", ".ico", ".lnk", ".tmp", ".log", ".pyc", ".chunk", ".blender"],
    "media_keywords": ["教程", "教学", "课程", "tutorial", "lecture", "讲课", "视频课", "实战"],
}


def load_cfg():
    cfg = dict(DEFAULT_CFG)
    if CFG_PATH.exists():
        try:
            cfg.update(json.loads(CFG_PATH.read_text(encoding="utf-8")))
        except Exception:
            pass
    return cfg


CATS = {
    "01_提示词库": ["分镜运镜", "角色设计", "场景氛围", "剧本写作", "配音音频", "商业营销", "通用模板"],
    "02_技能库": ["漫剧制作", "AI工具", "剪辑后期", "编程开发", "通用技能"],
    "03_方法论": ["工作流SOP", "叙事结构", "商业变现", "效率体系", "创作规则"],
    "04_底层理论": ["视听语言", "情绪设计", "AI生成原理"],
    "05_书籍教材": ["影视理论", "编剧写作", "AI教程", "参考资料"],
    "06_教学视频": [],
    "07_图片参考": [],
}
PROMPT_SUB = {
    "seedance": "分镜运镜", "分镜": "分镜运镜", "运镜": "分镜运镜", "镜头": "分镜运镜",
    "角色": "角色设计", "人物": "角色设计", "character": "角色设计",
    "场景": "场景氛围", "美术": "场景氛围", "风格": "场景氛围", "scene": "场景氛围",
    "剧本": "剧本写作", "写作": "剧本写作", "故事": "剧本写作", "writing": "剧本写作",
    "配音": "配音音频", "音频": "配音音频", "音乐": "配音音频", "music": "配音音频",
    "营销": "商业营销", "商业": "商业营销", "commercial": "商业营销", "爆款": "商业营销",
}
SKILL_SUB = {
    "漫剧": "漫剧制作", "分镜": "漫剧制作", "剧本": "漫剧制作", "漫": "漫剧制作", "剧": "漫剧制作",
    "剪": "剪辑后期", "视频": "剪辑后期", "音": "剪辑后期",
    "ai": "AI工具", "prompt": "AI工具", "agent": "AI工具",
    "code": "编程开发", "dev": "编程开发", "程序": "编程开发",
}
ILLEGAL = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def ensure_tree():
    for cat, subs in CATS.items():
        (HUB / cat).mkdir(parents=True, exist_ok=True)
        for s in subs:
            (HUB / cat / s).mkdir(parents=True, exist_ok=True)
    (HUB / "00_收件箱").mkdir(exist_ok=True)
    (HUB / "_索引").mkdir(exist_ok=True)


def load_index():
    if INDEX.exists():
        return json.loads(INDEX.read_text(encoding="utf-8"))
    return {"version": 2, "items": []}


def save_index(idx):
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(idx, ensure_ascii=False, indent=1), encoding="utf-8")


def sha256(p: Path):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def extract_title(p: Path):
    name = p.stem
    if p.suffix.lower() in (".md", ".txt", ".markdown"):
        try:
            for line in p.read_text(encoding="utf-8", errors="ignore").splitlines()[:12]:
                line = line.strip().lstrip("#").strip()
                if line and not line.startswith(("!", "[", ">", "-", "*")):
                    title = re.sub(r"[*_`\[\]()]|https?://\S+", "", line).strip()
                    if title:
                        name = title
                        break
        except Exception:
            pass
    title = ILLEGAL.sub("", name).strip(" .。")[:40].strip()
    if not re.search(r"[\u4e00-\u9fff]", title) and re.search(r"[\u4e00-\u9fff]", p.stem):
        title = ILLEGAL.sub("", p.stem).strip(" .。")[:40]
    return title or "未命名" + p.suffix


def classify(p: Path, media_keywords):
    n = p.name.lower()
    suffix = p.suffix.lower()
    if suffix in (".mp4", ".mkv", ".mov", ".avi", ".webm"):
        return "06_教学视频", ""
    if suffix in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
        return "07_图片参考", ""
    if suffix in (".pdf", ".epub", ".mobi"):
        return "05_书籍教材", "参考资料"
    if p.name == "SKILL.md" or "skill" in n:
        sub = next((v for k, v in SKILL_SUB.items() if k in n), "通用技能")
        return "02_技能库", sub
    if any(k in n for k in ("提示词", "prompt")):
        sub = next((v for k, v in PROMPT_SUB.items() if k in n), "通用模板")
        return "01_提示词库", sub
    if any(k in n for k in ("方法论", "sop", "工作流", "workflow", "流程", "清单")):
        return "03_方法论", "工作流SOP"
    if any(k in n for k in ("理论", "原理", "蒙太奇", "叙事", "视听")):
        return "04_底层理论", "视听语言"
    if any(k in n for k in ("教程", "教材", "课程", "book")):
        return "05_书籍教材", "AI教程"
    if suffix in (".md", ".txt"):
        try:
            head = p.read_text(encoding="utf-8", errors="ignore")[:1500].lower()
            for kws, cat, sub in (
                (("提示词", "prompt"), "01_提示词库", None),
                (("工作流", "sop", "流程"), "03_方法论", "工作流SOP"),
                (("理论", "原理"), "04_底层理论", None),
                (("教程", "课程"), "05_书籍教材", "AI教程"),
            ):
                if any(k in head for k in kws):
                    if cat == "01_提示词库":
                        sub = next((v for k, v in PROMPT_SUB.items() if k in head), "通用模板")
                    return cat, sub or ""
        except Exception:
            pass
    return "05_书籍教材", "参考资料"


def unique_target(cat_dir: Path, title: str, suffix: str):
    t = cat_dir / (title + suffix)
    i = 2
    while t.exists():
        t = cat_dir / f"{title}({i}){suffix}"
        i += 1
    return t


def file_card(src: Path, cat: str, sub: str, title: str, is_pointer: bool):
    d = HUB / cat
    if sub:
        d = d / sub
    d.mkdir(parents=True, exist_ok=True)
    prefix = "[视频]" if (cat == "06_教学视频" and is_pointer) else ""
    t = unique_target(d, prefix + title, ".md" if is_pointer else src.suffix.lower())
    if is_pointer:
        t.write_text(
            f"# {title}\n\n- 类型：大文件指针卡（原件未复制）\n- 原始路径：{src}\n- 大小：{src.stat().st_size/1048576:.1f} MB\n- 收录时间：{time.strftime('%Y-%m-%d %H:%M')}\n\n> 整理磁盘时请勿移动原文件。\n",
            encoding="utf-8")
    else:
        shutil.copy2(src, t)
    return t


def ingest_path(src: Path, cat_override=None, keep_source=True, idx=None, stats=None, cfg=None):
    if cfg is None:
        cfg = load_cfg()
    if idx is None:
        idx = load_index()
    stats = stats if stats is not None else {"copied": 0, "dupe": 0, "pointer": 0, "skip": 0}
    if src.is_dir():
        for f in sorted(src.rglob("*")):
            if f.is_file() and "_索引" not in f.parts:
                ingest_path(f, cat_override, keep_source, idx, stats, cfg)
        return stats
    suffix = src.suffix.lower()
    if suffix in (".tmp", ".crdownload", ".part", ".lnk") or suffix in cfg["exclude_ext"]:
        stats["skip"] += 1
        return stats
    known_srcs = idx.get("_srcs") or set()
    if str(src) in known_srcs:
        stats["skip"] += 1
        return stats
    h = sha256(src)
    if any(i["hash"] == h for i in idx["items"]):
        stats["dupe"] += 1
        print(f"  [重复] {src.name}（跳过）")
        return stats
    title = extract_title(src)
    if cat_override:
        cat, _, sub = cat_override.partition("/")
    else:
        cat, sub = classify(src, cfg.get("media_keywords", []))
    cat_dir = HUB / cat
    cat_dir.mkdir(parents=True, exist_ok=True)
    if sub:
        (cat_dir / sub).mkdir(parents=True, exist_ok=True)
        cat_dir = cat_dir / sub
    for sib in [i for i in idx["items"] if i["category"] == cat]:
        if difflib.SequenceMatcher(None, sib["title"], title).ratio() >= NEAR_DUPE_RATIO:
            stats["dupe"] += 1
            print(f"  [疑似重复] {src.name} ≈ {sib['title']}（跳过）")
            return stats
    size = src.stat().st_size
    limit = cfg.get("size_copy_limit_mb", 20) * 1048576
    ts = time.strftime("%Y-%m-%d %H:%M")
    if size <= limit:
        dest = unique_target(cat_dir, title, src.suffix.lower())
        shutil.copy2(src, dest)
        rel = str(dest.relative_to(HUB))
        stats["copied"] += 1
        print(f"  [收录] {rel}")
        is_pointer = False
    else:
        dest = file_card(src, cat, sub, title, True)
        rel = str(dest.relative_to(HUB))
        stats["pointer"] += 1
        print(f"  [指针卡] {rel}（{size/1048576:.0f}MB）")
        is_pointer = True
    idx["items"].append({"hash": h, "title": title, "category": cat, "rel_path": rel,
                         "src": str(src), "size": size, "ts": ts, "status": "已收录"})
    idx.setdefault("_srcs", [])
    idx["_srcs"].append(str(src))
    return stats


def cmd_ingest(args):
    ensure_tree()
    cfg = load_cfg()
    idx = load_index()
    src = Path(args.path).expanduser()
    if not src.exists():
        print(f"路径不存在：{src}")
        return
    stats = ingest_path(src, args.to, not args.move, idx, cfg=cfg)
    save_index(idx)
    print(f"\n完成：收录 {stats['copied']} · 指针卡 {stats['pointer']} · 重复跳过 {stats['dupe']} · 跳过 {stats['skip']}")


def cmd_scan(args):
    ensure_tree()
    cfg = load_cfg()
    idx = load_index()
    stats = {"copied": 0, "dupe": 0, "pointer": 0, "skip": 0}
    inbox = HUB / "00_收件箱"
    for f in sorted(inbox.rglob("*")):
        if f.is_file():
            before = (stats["copied"], stats["pointer"])
            ingest_path(f, None, False, idx, stats, cfg)
            if (stats["copied"], stats["pointer"]) != before and args.tidy:
                f.unlink(missing_ok=True)
    save_index(idx)
    print(f"\n收件箱处理完成：收录 {stats['copied']} · 指针卡 {stats['pointer']} · 重复跳过 {stats['dupe']}")


def cmd_harvest(args):
    ensure_tree()
    cfg = load_cfg()
    idx = load_index()
    srcs = set(idx.get("_srcs", []))
    hashes = {i["hash"] for i in idx["items"]}
    injected = {p.name.lower() for p in Path(cfg["inject_target"]).iterdir()} if Path(cfg["inject_target"]).exists() else set()
    roots = args.roots or cfg["harvest_roots"]
    deadline = time.time() + args.max_min * 60
    stats = {"skill": 0, "prompt": 0, "video": 0, "book": 0, "method": 0, "dupe": 0}
    mk = cfg.get("media_keywords", [])

    def add_item(h, title, cat, rel, src, size, status):
        idx["items"].append({"hash": h, "title": title, "category": cat, "rel_path": rel,
                             "src": str(src), "size": size, "ts": time.strftime("%Y-%m-%d %H:%M"),
                             "status": status})
        idx.setdefault("_srcs", []).append(str(src))

    def walk(root):
        nonlocal deadline
        rootp = Path(root)
        if not rootp.exists():
            return
        for dirpath, dirnames, filenames in os.walk(rootp):
            dirnames[:] = [d for d in dirnames if d not in cfg["exclude_dirs"]
                           and not d.startswith((".", "$"))]
            if time.time() > deadline:
                raise TimeoutError
            for fn in filenames:
                p = Path(dirpath) / fn
                if str(p) in srcs:
                    continue
                suffix = p.suffix.lower()
                if suffix in cfg["exclude_ext"]:
                    continue
                low = fn.lower()
                # ① 技能：任何位置的 SKILL.md
                if fn == "SKILL.md":
                    sd = p.parent
                    if str(sd).startswith(str(Path(cfg["inject_target"]).resolve())):
                        continue   # 主系统注入目录本身不收割（已有指针卡体系）
                    key = f"skill:{sd}"
                    if key in srcs:
                        continue
                    try:
                        head = p.read_text(encoding="utf-8", errors="ignore")[:800]
                    except Exception:
                        continue
                    m = re.search(r"name:\s*[\"']?([\w-]+)", head)
                    ename = m.group(1) if m else sd.name
                    m2 = re.search(r"description:\s*[\"']?(.+?)[\"']?\s*$", head, re.M)
                    desc = (m2.group(1).strip() if m2 else "")[:60]
                    title0 = desc[:22] if re.search(r"[\u4e00-\u9fff]", desc) else ename
                    title = ILLEGAL.sub("", title0).strip() or ename
                    status = "已注入" if ename.lower() in injected else "待整理"
                    sub = next((v for k, v in SKILL_SUB.items() if k in (ename + desc).lower()), "通用技能")
                    d = HUB / "02_技能库" / sub
                    d.mkdir(parents=True, exist_ok=True)
                    card = unique_target(d, f"[{status}]技能·{title}（{ename}）", ".md")
                    card.write_text(
                        f"# [{status}] {title}\n\n- 技能名：{ename}\n- 状态：{status}\n- 简介新版：{desc}\n- 所在位置：{sd}\n- 收录时间：{time.strftime('%Y-%m-%d %H:%M')}\n\n"
                        + ("> 已注入主系统，勿移动。\n" if status == "已注入" else "> 待整理：确认后运行 promote 注入主系统。\n"),
                        encoding="utf-8")
                    rel = str(card.relative_to(HUB))
                    add_item(hashlib.sha256(str(sd).encode()).hexdigest()[:32], title,
                             "02_技能库", rel, sd, 0, status)
                    srcs.add(str(sd)); srcs.add(str(p)); srcs.add(key)
                    stats["skill"] += 1
                    continue
                # ② 教学视频（关键词 + 常见视频格式）→ 指针卡
                if suffix in (".mp4", ".mkv", ".mov", ".webm"):
                    if any(k in low or k in str(p.parent).lower() for k in mk):
                        if p.name in srcs or str(p) in srcs:
                            continue
                        title = extract_title(p)
                        card = file_card(p, "06_教学视频", "", title, True)
                        rel = str(card.relative_to(HUB))
                        add_item(sha256(p) if p.stat().st_size < 500*1048576 else f"vid:{p}", title,
                                 "06_教学视频", rel, p, p.stat().st_size, "已收录")
                        srcs.add(str(p))
                        stats["video"] += 1
                    continue
                # ③ 书籍教材（pdf/epub 且名称含学习关键词）
                if suffix in (".pdf", ".epub") and any(k in low for k in ("教程", "教材", "指南", "手册", "书", "理论", "圣经")):
                    if p.stat().st_size > 300 * 1048576 or str(p) in srcs:
                        continue
                    h = sha256(p)
                    if h in hashes:
                        stats["dupe"] += 1
                        continue
                    title = extract_title(p)
                    card = file_card(p, "05_书籍教材", "参考资料", title, p.stat().st_size > cfg.get("size_copy_limit_mb", 20)*1048576)
                    rel = str(card.relative_to(HUB))
                    add_item(h, title, "05_书籍教材", rel, p, p.stat().st_size, "已收录")
                    hashes.add(h); srcs.add(str(p))
                    stats["book"] += 1
                    continue
                # ④ 提示词/方法论文档（md/txt，按名或内容命中）
                if suffix in (".md", ".txt") and p.stat().st_size < 1048576:
                    hit = any(k in low for k in ("提示词", "prompt", "方法论", "工作流", "sop"))
                    head = ""
                    if not hit:
                        try:
                            head = p.read_text(encoding="utf-8", errors="ignore")[:1200].lower()
                        except Exception:
                            continue
                        hit = ("提示词" in head or "prompt" in head or "方法论" in head
                               or ("漫剧" in head and "分镜" in head))
                    if not hit:
                        continue
                    h = sha256(p)
                    if h in hashes:
                        stats["dupe"] += 1
                        continue
                    title = extract_title(p)
                    cat, sub = classify(p, mk)
                    is_ptr = p.stat().st_size > cfg.get("size_copy_limit_mb", 20)*1048576
                    card = file_card(p, cat, sub, title, is_ptr)
                    rel = str(card.relative_to(HUB))
                    add_item(h, title, cat, rel, p, p.stat().st_size, "已收录")
                    hashes.add(h); srcs.add(str(p))
                    if cat == "01_提示词库":
                        stats["prompt"] += 1
                    else:
                        stats["method"] += 1
                    continue

    try:
        for r in roots:
            print(f"扫描 {r} ...")
            walk(r)
    except TimeoutError:
        print(f"已达 {args.max_min} 分钟时间预算，剩余内容下次运行 harvest 继续收割（去重保证不重复）。")
    save_index(idx)
    print(f"\n收割完成：技能 {stats['skill']} · 提示词 {stats['prompt']} · 教学视频 {stats['video']} · 书籍 {stats['book']} · 方法论 {stats['method']} · 重复 {stats['dupe']}")


def cmd_promote(args):
    cfg = load_cfg()
    idx = load_index()
    target = Path(cfg["inject_target"])
    target.mkdir(parents=True, exist_ok=True)
    pend = [i for i in idx["items"] if i.get("status") == "待整理"]
    if not pend:
        print("没有待整理技能。")
        return
    pick = None
    if args.key.isdigit():
        pick = pend[int(args.key) - 1]
    else:
        for i in pend:
            if args.key.lower() in i["rel_path"].lower() or args.key in i["title"]:
                pick = i
                break
    if not pick:
        print(f"未匹配到待整理技能。当前 {len(pend)} 条：")
        for n, i in enumerate(pend, 1):
            print(f"  {n}. {i['title']}  (源: {i['src']})")
        return
    src = Path(pick["src"])
    dest = target / src.name
    if dest.exists():
        print(f"主系统已存在同名技能 {dest.name}，跳过（如需覆盖请手动处理）。")
        return
    shutil.copytree(src, dest)
    pick["status"] = "已注入"
    save_index(idx)
    print(f"已注入主系统：{dest}")


def cmd_report(args):
    idx = load_index()
    by_cat, by_status = {}, {}
    for i in idx["items"]:
        by_cat[i["category"]] = by_cat.get(i["category"], 0) + 1
        by_status[i.get("status", "已收录")] = by_status.get(i.get("status", "已收录"), 0) + 1
    print(f"知识中枢共收录 {len(idx['items'])} 条")
    for cat in sorted(by_cat):
        print(f"  {cat}: {by_cat[cat]}")
    print("状态分布：" + " · ".join(f"{k} {v}" for k, v in by_status.items()))


def cmd_dedupe(args):
    idx = load_index()
    seen, dupes = {}, []
    for i in idx["items"]:
        seen.setdefault(i["hash"], []).append(i)
    for h, items in seen.items():
        if len(items) > 1:
            dupes.append(items)
    print(f"完全重复组：{len(dupes)}")
    for items in dupes:
        for i in items[1:]:
            print(f"  重复: {i['rel_path']}  (源: {i['src']})")
            if args.delete:
                (HUB / i["rel_path"]).unlink(missing_ok=True)
                idx["items"].remove(i)
    if args.delete and dupes:
        save_index(idx)
        print("已删除重复项并更新索引")


def main():
    ap = argparse.ArgumentParser(description="知识中枢管理器 v2（便携）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p1 = sub.add_parser("ingest"); p1.add_argument("path")
    p1.add_argument("--to", default=None); p1.add_argument("--move", action="store_true")
    p2 = sub.add_parser("scan"); p2.add_argument("--tidy", action="store_true")
    p3 = sub.add_parser("harvest")
    p3.add_argument("--roots", nargs="*", default=None)
    p3.add_argument("--max-min", type=int, default=None)
    p4 = sub.add_parser("promote"); p4.add_argument("key")
    sub.add_parser("report")
    p6 = sub.add_parser("dedupe"); p6.add_argument("--delete", action="store_true")
    a = ap.parse_args()
    ensure_tree()
    {"ingest": cmd_ingest, "scan": cmd_scan, "harvest": cmd_harvest,
     "promote": cmd_promote, "report": cmd_report, "dedupe": cmd_dedupe}[a.cmd](a)


if __name__ == "__main__":
    main()
