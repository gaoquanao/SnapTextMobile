#!/usr/bin/env python3
"""生成随 App 分发的快捷指令配方文件（.shortcut）。

配方（用户在设置页一键导入，导入后可在快捷指令 App 中自由修改）：
  A 拾文·大爆炸      截屏 → 大爆炸截图识别（默认推荐）
  B 拾文·静默归档    截屏 → 静默归档截图 → 显示通知

产物写入 SnapText/Resources/Shortcuts/，随后用 `shortcuts sign -m anyone` 签名，
签名后导入端无需打开「允许不受信任的快捷指令」。

格式依据：真实 .shortcut 反序列化样例（动作 UUID / OutputUUID 变量引用 /
WFTextTokenAttachment / WFTextTokenString）与 AppIntentDescriptor 文档。
"""
import plistlib
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "SnapText" / "Resources" / "Shortcuts"
SOURCE_DIR = ROOT / "Scripts" / "Shortcuts"

BUNDLE_ID = "me.snaptext.app"
TEAM_ID = "QGC87Z9JX3"

BANG_INTENT = ("SnapBangIntent", "大爆炸截图识别")
ARCHIVE_INTENT = ("SnapArchiveIntent", "静默归档截图")

ICON = {"WFWorkflowIconGlyphNumber": 59511, "WFWorkflowIconStartColor": 4282601983}


def new_uuid() -> str:
    return str(uuid.uuid4()).upper()


def screenshot_action(action_uuid: str) -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.takescreenshot",
        "WFWorkflowActionParameters": {"UUID": action_uuid},
    }


def intent_action(intent: tuple[str, str], action_uuid: str, image_ref: str,
                  image_output_name: str) -> dict:
    identifier, title = intent
    return {
        "WFWorkflowActionIdentifier": f"{BUNDLE_ID}.{identifier}",
        "WFWorkflowActionParameters": {
            "UUID": action_uuid,
            "AppIntentDescriptor": {
                "BundleIdentifier": BUNDLE_ID,
                "Name": title,
                "TeamIdentifier": TEAM_ID,
                "AppIntentIdentifier": identifier,
            },
            "image": variable_ref(image_ref, image_output_name),
        },
    }


def variable_ref(output_uuid: str, output_name: str) -> dict:
    """非展示型参数引用前序动作输出。"""
    return {
        "Value": {
            "OutputName": output_name,
            "OutputUUID": output_uuid,
            "Type": "ActionOutput",
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def text_with_ref(prefix: str, output_uuid: str, output_name: str) -> dict:
    """展示型文本参数中嵌入变量（\ufffc 为占位符，范围为 UTF-16 码元）。"""
    return {
        "Value": {
            "attachmentsByRange": {
                f"{{{len(prefix)}, 1}}": {
                    "OutputName": output_name,
                    "OutputUUID": output_uuid,
                    "Type": "ActionOutput",
                }
            },
            "string": f"{prefix}\ufffc",
        },
        "WFSerializationType": "WFTextTokenString",
    }


def notification_action(action_uuid: str, body: dict) -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.notification",
        "WFWorkflowActionParameters": {
            "UUID": action_uuid,
            "WFNotificationActionTitle": "拾文",
            "WFNotificationActionBody": body,
        },
    }


def wrap(actions: list) -> dict:
    return {
        "WFWorkflowClientVersion": "2700.0.4",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": ICON,
        "WFWorkflowImportQuestions": [],
        "WFWorkflowTypes": [],
        "WFWorkflowInputContentItemClasses": [],
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowActions": actions,
    }


def recipe_bang() -> dict:
    shot = new_uuid()
    intent = new_uuid()
    return wrap([
        screenshot_action(shot),
        intent_action(BANG_INTENT, intent, shot, "Screenshot"),
    ])


def recipe_archive() -> dict:
    shot = new_uuid()
    archive = new_uuid()
    notify = new_uuid()
    return wrap([
        screenshot_action(shot),
        intent_action(ARCHIVE_INTENT, archive, shot, "Screenshot"),
        notification_action(
            notify,
            text_with_ref("已归档：", archive, "静默归档截图"),
        ),
    ])


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    recipes = {
        "拾文·大爆炸": recipe_bang(),
        "拾文·静默归档": recipe_archive(),
    }
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    # 签名先写到临时目录再拷贝进仓库：签名服务会把它的输出当临时文件延迟回收，
    # 直接以目标路径作为 -o 会导致成品几分钟后被无声删掉。
    with tempfile.TemporaryDirectory() as staging:
        for name, wf in recipes.items():
            raw = SOURCE_DIR / f"{name}.shortcut"
            with open(raw, "wb") as f:
                plistlib.dump(wf, f, fmt=plistlib.FMT_BINARY)
            staged = Path(staging) / f"{name}.shortcut"
            proc = subprocess.run(
                ["shortcuts", "sign", "-m", "anyone", "-i", str(raw), "-o", str(staged)],
                capture_output=True, text=True,
            )
            if proc.returncode != 0:
                print(f"!! 签名失败 {name}: {proc.stderr.strip()}")
                print(f"   未签名文件保留在 {raw}")
                return 1
            signed = OUT_DIR / f"{name}.shortcut"
            shutil.copyfile(staged, signed)
            signed.chmod(0o644)
            print(f"✓ {signed} ({signed.stat().st_size} B)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
