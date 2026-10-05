import XCTest

/// 内置快捷指令配方的回归测试。
/// 解析仓库内的未签名源文件（Scripts/Shortcuts/，由 Scripts/build-shortcuts.py 生成），
/// 校验动作序列、变量引用与 App Intent 描述符；并确认 App 包内带了签名后的成品。
final class ShortcutRecipeTests: XCTestCase {
    private func loadRecipeSource(_ name: String) throws -> [String: Any] {
        // #filePath 指向本文件，上两级即仓库根目录。
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appending(path: "Scripts/Shortcuts/\(name).shortcut")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any], "配方源文件应为 plist")
    }

    private func actionUUID(_ action: [String: Any]) throws -> String {
        let params = try XCTUnwrap(action["WFWorkflowActionParameters"] as? [String: Any])
        return try XCTUnwrap(params["UUID"] as? String, "动作应带 UUID")
    }

    /// 取出参数中引用的动作输出 UUID（WFTextTokenAttachment / WFTextTokenString 两种形态）。
    private func referencedUUID(_ parameter: [String: Any]) throws -> String {
        let value = try XCTUnwrap(parameter["Value"] as? [String: Any])
        if let output = value["OutputUUID"] as? String {
            return output
        }
        let attachments = try XCTUnwrap(value["attachmentsByRange"] as? [String: Any])
        let attachment = try XCTUnwrap(attachments.values.first as? [String: Any])
        return try XCTUnwrap(attachment["OutputUUID"] as? String)
    }

    func testBangRecipeWiresScreenshotIntoIntent() throws {
        let wf = try loadRecipeSource("拾文·大爆炸")
        let actions = try XCTUnwrap(wf["WFWorkflowActions"] as? [[String: Any]])
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0]["WFWorkflowActionIdentifier"] as? String, "is.workflow.actions.takescreenshot")

        let intent = actions[1]
        XCTAssertEqual(intent["WFWorkflowActionIdentifier"] as? String, "me.snaptext.app.SnapBangIntent")
        let params = try XCTUnwrap(intent["WFWorkflowActionParameters"] as? [String: Any])
        let descriptor = try XCTUnwrap(params["AppIntentDescriptor"] as? [String: Any])
        XCTAssertEqual(descriptor["BundleIdentifier"] as? String, "me.snaptext.app")
        XCTAssertEqual(descriptor["AppIntentIdentifier"] as? String, "SnapBangIntent")
        XCTAssertEqual(descriptor["TeamIdentifier"] as? String, "QGC87Z9JX3")

        // 「截屏」动作的输出接到 intent 的 image 参数
        let shotUUID = try actionUUID(actions[0])
        let imageRef = try XCTUnwrap(params["image"] as? [String: Any])
        XCTAssertEqual(imageRef["WFSerializationType"] as? String, "WFTextTokenAttachment")
        XCTAssertEqual(try referencedUUID(imageRef), shotUUID)
    }

    func testArchiveRecipeWiresScreenshotAndNotification() throws {
        let wf = try loadRecipeSource("拾文·静默归档")
        let actions = try XCTUnwrap(wf["WFWorkflowActions"] as? [[String: Any]])
        XCTAssertEqual(actions.count, 3)
        XCTAssertEqual(actions[0]["WFWorkflowActionIdentifier"] as? String, "is.workflow.actions.takescreenshot")
        XCTAssertEqual(actions[1]["WFWorkflowActionIdentifier"] as? String, "me.snaptext.app.SnapArchiveIntent")
        XCTAssertEqual(actions[2]["WFWorkflowActionIdentifier"] as? String, "is.workflow.actions.notification")

        let shotUUID = try actionUUID(actions[0])
        let archiveUUID = try actionUUID(actions[1])
        let archiveParams = try XCTUnwrap(actions[1]["WFWorkflowActionParameters"] as? [String: Any])
        XCTAssertEqual(try referencedUUID(try XCTUnwrap(archiveParams["image"] as? [String: Any])), shotUUID)

        // 通知正文引用归档结果
        let notifyParams = try XCTUnwrap(actions[2]["WFWorkflowActionParameters"] as? [String: Any])
        XCTAssertEqual(notifyParams["WFNotificationActionTitle"] as? String, "拾文")
        let body = try XCTUnwrap(notifyParams["WFNotificationActionBody"] as? [String: Any])
        XCTAssertEqual(body["WFSerializationType"] as? String, "WFTextTokenString")
        XCTAssertEqual(try referencedUUID(body), archiveUUID)
    }

    func testSignedRecipesAreBundled() throws {
        for name in ["拾文·大爆炸", "拾文·静默归档"] {
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: name, withExtension: "shortcut"),
                "App 包内应包含签名后的配方 \(name)"
            )
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 1000, "签名后的配方文件不应为空")
        }
    }
}
