import Foundation

enum LegalDocumentType: String, Identifiable {
    case userAgreement
    case privacyPolicy

    var id: String { rawValue }
}

struct LegalSection: Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

enum LegalDocuments {
    static func title(for document: LegalDocumentType, languageCode: String) -> String {
        switch document {
        case .userAgreement:
            return languageCode.hasPrefix("zh") ? "用户协议" : "User Agreement"
        case .privacyPolicy:
            return languageCode.hasPrefix("zh") ? "隐私政策" : "Privacy Policy"
        }
    }

    static func sections(for document: LegalDocumentType, languageCode: String) -> [LegalSection] {
        languageCode.hasPrefix("zh")
            ? chineseSections(for: document)
            : englishSections(for: document)
    }

    private static func chineseSections(for document: LegalDocumentType) -> [LegalSection] {
        switch document {
        case .userAgreement:
            return [
                LegalSection(
                    title: "欢迎使用 Vivide",
                    body: """
                    欢迎使用 Vivide（以下简称「本 App」）。在使用本 App 前，请仔细阅读本用户协议。开始使用即表示您同意受本协议约束。
                    """
                ),
                LegalSection(
                    title: "服务说明",
                    body: """
                    本 App 提供相册信息查看、筛选、排序、EXIF 读取，以及将所选图片保存至 App 本地存储等功能。本 App 不会在未经您操作的情况下修改或删除系统相册中的原始照片。
                    """
                ),
                LegalSection(
                    title: "使用规范",
                    body: """
                    您应合法、正当地使用本 App，不得利用本 App 从事任何违法或侵犯他人合法权益的行为。您应确保对所导入、查看的图片拥有合法权利。
                    """
                ),
                LegalSection(
                    title: "相册与本地存储",
                    body: """
                    本 App 需要您授权访问系统相册以读取照片信息；导入功能会将您选择的图片副本保存至设备本地 Documents 目录。删除本地库中的图片仅移除 App 内副本，不会删除系统相册原图。
                    """
                ),
                LegalSection(
                    title: "免责声明",
                    body: """
                    本 App 按「现状」提供，不对信息的完整性、准确性作绝对保证。因设备故障、系统限制或用户误操作导致的数据丢失，开发者不承担法律责任，建议您自行备份重要数据。
                    """
                ),
                LegalSection(
                    title: "协议变更",
                    body: """
                    我们可能适时更新本协议。更新后的协议将在 App 内公布，继续使用本 App 即视为接受更新内容。
                    """
                ),
                LegalSection(
                    title: "更新日期",
                    body: "最后更新：2026 年 7 月 4 日"
                )
            ]
        case .privacyPolicy:
            return [
                LegalSection(
                    title: "概述",
                    body: """
                    Vivide 重视您的隐私。本隐私政策说明我们如何收集、使用与保护您的信息。本 App 主要在本机运行，不会将您的照片上传至开发者服务器。
                    """
                ),
                LegalSection(
                    title: "我们收集的信息",
                    body: """
                    • 相册访问：在您授权后，读取照片及元数据（如分辨率、拍摄时间、EXIF）用于展示与分析。
                    • 本地导入数据：您主动导入的图片副本、文件夹名称、隐藏标记等，均存储在设备本地。
                    • 应用设置：语言、外观、导入文件夹偏好等，保存在设备 UserDefaults 中。
                    """
                ),
                LegalSection(
                    title: "信息的使用",
                    body: """
                    上述信息仅用于实现 App 功能，包括展示相册、筛选排序、本地库管理与个性化设置，不会用于广告定向或出售给第三方。
                    """
                ),
                LegalSection(
                    title: "信息存储与安全",
                    body: """
                    导入的图片与清单文件保存在 App 沙盒 Documents 目录，受 iOS 系统隔离保护。卸载 App 后，相关本地数据将被清除。
                    """
                ),
                LegalSection(
                    title: "权限说明",
                    body: """
                    • 照片权限：用于读取相册与导入所选图片。
                    您可在系统「设置 → 隐私 → 照片」中随时更改或撤销授权。撤销后，部分功能将无法使用。
                    """
                ),
                LegalSection(
                    title: "第三方服务",
                    body: """
                    本 App 不集成第三方广告或统计 SDK，不会通过第三方收集您的个人照片内容。
                    """
                ),
                LegalSection(
                    title: "您的权利",
                    body: """
                    您可随时在 App 内删除本地导入的图片与文件夹，或在系统设置中关闭相册权限、卸载 App 以清除相关数据。
                    """
                ),
                LegalSection(
                    title: "政策更新",
                    body: """
                    我们可能更新本隐私政策，并在 App 内发布最新版本。重大变更将通过 App 内提示告知。
                    """
                ),
                LegalSection(
                    title: "更新日期",
                    body: "最后更新：2026 年 7 月 4 日"
                )
            ]
        }
    }

    private static func englishSections(for document: LegalDocumentType) -> [LegalSection] {
        switch document {
        case .userAgreement:
            return [
                LegalSection(
                    title: "Welcome to Vivide",
                    body: """
                    Welcome to Vivide (the "App"). Please read this User Agreement carefully before use. By using the App, you agree to these terms.
                    """
                ),
                LegalSection(
                    title: "Service Description",
                    body: """
                    The App lets you browse photo metadata, filter and sort images, read EXIF data, and save selected photos to local in-app storage. The App will not modify or delete originals in your system photo library without your action.
                    """
                ),
                LegalSection(
                    title: "Acceptable Use",
                    body: """
                    You must use the App lawfully and must not use it for illegal purposes or to infringe others' rights. You are responsible for ensuring you have the right to import and view the photos you select.
                    """
                ),
                LegalSection(
                    title: "Photo Library & Local Storage",
                    body: """
                    The App requires photo library access to read image information. Importing saves copies of selected photos to the device's Documents directory. Deleting items from the local library removes only in-app copies, not originals in Photos.
                    """
                ),
                LegalSection(
                    title: "Disclaimer",
                    body: """
                    The App is provided "as is" without warranties of completeness or accuracy. We are not liable for data loss caused by device failure, system limits, or user error. Please back up important data yourself.
                    """
                ),
                LegalSection(
                    title: "Changes",
                    body: """
                    We may update this Agreement from time to time. Updated terms will be published in the App. Continued use constitutes acceptance.
                    """
                ),
                LegalSection(
                    title: "Last Updated",
                    body: "Last updated: July 4, 2026"
                )
            ]
        case .privacyPolicy:
            return [
                LegalSection(
                    title: "Overview",
                    body: """
                    Vivide respects your privacy. This Privacy Policy explains how we handle your information. The App runs primarily on your device and does not upload your photos to our servers.
                    """
                ),
                LegalSection(
                    title: "Information We Collect",
                    body: """
                    • Photo library access: With your permission, we read photos and metadata (resolution, dates, EXIF) for display and analysis.
                    • Local import data: Photos you import, folder names, and hide flags stored locally on your device.
                    • App settings: Language, appearance, and import preferences stored in UserDefaults on device.
                    """
                ),
                LegalSection(
                    title: "How We Use Information",
                    body: """
                    Information is used only to provide App features such as album browsing, filtering, local library management, and personalization. We do not use it for ads or sell it to third parties.
                    """
                ),
                LegalSection(
                    title: "Storage & Security",
                    body: """
                    Imported photos and manifests are stored in the App sandbox Documents directory, protected by iOS isolation. Uninstalling the App removes this local data.
                    """
                ),
                LegalSection(
                    title: "Permissions",
                    body: """
                    • Photos: Required to read your library and import selected images.
                    You can change or revoke access anytime in Settings → Privacy → Photos. Some features will not work without permission.
                    """
                ),
                LegalSection(
                    title: "Third Parties",
                    body: """
                    The App does not integrate third-party advertising or analytics SDKs and does not collect your photo content through third parties.
                    """
                ),
                LegalSection(
                    title: "Your Rights",
                    body: """
                    You may delete imported photos and folders in the App, revoke photo access in system settings, or uninstall the App to remove related data.
                    """
                ),
                LegalSection(
                    title: "Policy Updates",
                    body: """
                    We may update this Privacy Policy and publish the latest version in the App. Material changes will be communicated in-app.
                    """
                ),
                LegalSection(
                    title: "Last Updated",
                    body: "Last updated: July 4, 2026"
                )
            ]
        }
    }
}
