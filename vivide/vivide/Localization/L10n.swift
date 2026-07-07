import Foundation

enum L10nKey: String {
    case tabAlbum, tabLocal, tabSettings
    case appName, selectPhotos
    case settingsTitle, settingsLanguage, settingsAppearance, settingsAbout
    case settingsLegal, userAgreement, privacyPolicy
    case settingsLocalLibrary, settingsShowHiddenPhotos, settingsShowHiddenPhotosHint
    case settingsVersion, settingsDescription
    case settingsBSideTitle, settingsBSideHint, settingsBSideOpen, bsideClose
    case languageSystem, languageZhHans, languageEnglish
    case appearanceSystem, appearanceLight, appearanceDark

    case permissionExploreTitle, permissionExploreMessage, permissionAllow
    case permissionDeniedTitle, permissionDeniedMessage, permissionOpenSettings

    case myAlbum, reset, localCount
    case loadingAlbum, noPhotos, noSearchResults, noFilterResults, clearFilters
    case totalPhotos, showingPhotos, selectToImport
    case albumOverview, filterShowing
    case searchPlaceholder, sortLabel
    case importSelect, importFiltered, copyInfo, shareInfo, copied
    case importFolderLabel, folderAll, newFolder, newFolderTitle, newFolderPlaceholder, createFolder
    case folderNameEmpty, folderNameExists, localFolderFilter, storageFolder
    case manageFolders, renameFolder, deleteFolder, renameFolderTitle, save
    case deleteFolderTitle, deleteFolderMessage, deleteEmptyFolderMessage
    case moveToAll, deleteFolderAndPhotos, folderRenamed, folderDeleted
    case noCustomFolders, folderPhotoCount
    case photoDetail, basicInfo, captureInfo, exifInfo, specialTags, localInfo
    case loadingEXIF, localPhoto, deleteLocalTitle, deleteLocalMessage, delete
    case cancel, done, manage, selectAll, deselectAll, selectedCount
    case importToLocal, importing, hide, unhide, deleteSelected
    case setHidden, unsetHidden, hiddenLabel, yes, no
    case savedLocally, localLibrarySummary, localEmpty, localEmptyHint
    case noHiddenPhotos, noVisiblePhotos, hiddenBadge, folderEmptyPhotos
    case importSuccess, importSkipped, importFailed, nothingToImport
    case hiddenCount, unhiddenCount, deletedCount, setHiddenOne, unsetHiddenOne

    case dateAll, dateToday, dateWeek, dateMonth, dateYear, dateCustom
    case catAll, catFavorites, catVideos, catScreenshots, catLivePhoto, catLocation
    case sortNewest, sortOldest, sortResHigh, sortResLow, sortName
    case libVisible, libHidden, libAll

    case filename, resolution, aspectRatio, fileSize, mediaType, source, duration
    case created, modified, location, favorite, hidden, importedAt, shotAt
    case direction, unknown, calculating

    case retry, bsideLoadFailed, noSearchResultsWithQuery
    case limitedLibraryHint, limitedLibraryManage
    case exportHeader, exportDivider, exportFromVivide

    case mediaImage, mediaVideo, mediaAudio, mediaUnknown
    case subtypePanorama, subtypeHDR, subtypeScreenshot, subtypeLivePhoto, subtypeDepthEffect
    case sourceUserLibrary, sourceCloudShared, sourceITunes, sourceOther

    case exifMake, exifModel, exifSoftware, exifLens, exifFocalLength, exifAperture
    case exifISO, exifShutter, exifFlash, exifWhiteBalance, exifColorSpace
    case exifWidth, exifHeight, exifLatitude, exifLongitude, exifAltitude
    case exifFlashOff, exifFlashOn, exifWbAuto, exifWbManual
    case exifOrientationNormal, exifOrientation180, exifOrientationCW90, exifOrientationCCW90
    case exifOrientationUnknown, exifExposureSeconds, exifExposureFraction
}

enum L10n {
    static func string(_ key: L10nKey, language code: String) -> String {
        table[code]?[key] ?? table["zh-Hans"]?[key] ?? key.rawValue
    }

    private static let table: [String: [L10nKey: String]] = [
        "zh-Hans": zhStrings,
        "en": enStrings
    ]

    private static let zhStrings: [L10nKey: String] = [
        .tabAlbum: "相册", .tabLocal: "本地库", .tabSettings: "设置",
        .appName: "Vivide", .selectPhotos: "选择图片",
        .settingsTitle: "设置", .settingsLanguage: "语言", .settingsAppearance: "外观",
        .settingsLocalLibrary: "本地库", .settingsShowHiddenPhotos: "显示隐藏图片",
        .settingsShowHiddenPhotosHint: "开启后，本地库默认列表中会显示已隐藏的图片",
        .settingsAbout: "关于", .settingsVersion: "版本", .settingsDescription: "柔美风格的相册信息查看工具",
        .settingsBSideTitle: "探索", .settingsBSideHint: "在应用内打开网页版体验。",
        .settingsBSideOpen: "打开网页版", .bsideClose: "返回应用",
        .settingsLegal: "法律信息", .userAgreement: "用户协议", .privacyPolicy: "隐私政策",
        .languageSystem: "跟随系统", .languageZhHans: "简体中文", .languageEnglish: "English",
        .appearanceSystem: "跟随系统", .appearanceLight: "浅色模式", .appearanceDark: "深色模式",
        .permissionExploreTitle: "探索你的相册",
        .permissionExploreMessage: "Vivide 需要访问相册，帮你查看每一张照片的详细信息，并批量保存到 App 本地。",
        .permissionAllow: "允许访问相册",
        .permissionDeniedTitle: "无法访问相册",
        .permissionDeniedMessage: "请在「设置 → 隐私 → 照片」中允许 Vivide 访问你的相册。",
        .permissionOpenSettings: "打开设置",
        .myAlbum: "我的相册", .reset: "重置", .localCount: "本地",
        .loadingAlbum: "正在读取相册…", .noPhotos: "相册中暂无照片或视频",
        .noSearchResults: "未找到匹配的图片", .noFilterResults: "当前筛选条件下暂无图片",
        .clearFilters: "清除筛选", .totalPhotos: "共 %d 项",
        .showingPhotos: "显示 %d / %d 项", .selectToImport: "点选要导入的媒体",
        .albumOverview: "相册概览", .filterShowing: "筛选 %d 张",
        .searchPlaceholder: "搜索文件名或类型…", .sortLabel: "排序",
        .importSelect: "选择图片导入", .importFiltered: "导入当前筛选结果",
        .importFolderLabel: "导入到文件夹", .folderAll: "全部",
        .newFolder: "新建", .newFolderTitle: "新建文件夹",
        .newFolderPlaceholder: "文件夹名称", .createFolder: "创建",
        .folderNameEmpty: "请输入文件夹名称", .folderNameExists: "该文件夹名称已存在",
        .localFolderFilter: "文件夹", .storageFolder: "存储文件夹",
        .manageFolders: "管理", .renameFolder: "重命名", .deleteFolder: "删除文件夹",
        .renameFolderTitle: "重命名文件夹", .save: "保存",
        .deleteFolderTitle: "删除文件夹？",
        .deleteFolderMessage: "「%@」中有 %d 张照片。可将照片移至「全部」，或一并删除。",
        .deleteEmptyFolderMessage: "确定删除文件夹「%@」？",
        .moveToAll: "移至全部", .deleteFolderAndPhotos: "删除文件夹及照片",
        .folderRenamed: "文件夹已重命名", .folderDeleted: "文件夹已删除",
        .noCustomFolders: "暂无自定义文件夹", .folderPhotoCount: "%d 张照片",
        .copyInfo: "复制信息", .shareInfo: "分享信息", .copied: "已复制到剪贴板",
        .photoDetail: "图片详情", .basicInfo: "基本信息", .captureInfo: "拍摄信息",
        .exifInfo: "EXIF 信息", .specialTags: "特殊标记", .localInfo: "本地信息",
        .loadingEXIF: "正在读取 EXIF…", .localPhoto: "本地图片",
        .deleteLocalTitle: "删除本地图片？", .deleteLocalMessage: "此操作仅删除 App 内副本，不会删除系统相册中的原图。",
        .delete: "删除", .cancel: "取消", .done: "完成", .manage: "管理",
        .selectAll: "全选", .deselectAll: "取消全选", .selectedCount: "已选 %d 张",
        .importToLocal: "导入到本地（%d）", .importing: "正在导入…",
        .hide: "设为隐藏", .unhide: "取消隐藏", .deleteSelected: "删除选中（%d）",
        .setHidden: "设为隐藏", .unsetHidden: "取消隐藏", .hiddenLabel: "隐藏",
        .yes: "是", .no: "否",
        .savedLocally: "已保存到 App", .localLibrarySummary: "共 %d 张 · %@",
        .localEmpty: "本地库为空", .localEmptyHint: "在「相册」页选择图片，批量导入到 App 本地存储",
        .noHiddenPhotos: "暂无隐藏图片", .noVisiblePhotos: "暂无可见图片", .hiddenBadge: "隐藏",
        .folderEmptyPhotos: "当前文件夹暂无图片",
        .importSuccess: "成功导入 %d 张", .importSkipped: "跳过 %d 张（已存在）",
        .importFailed: "失败 %d 张", .nothingToImport: "没有可导入的图片",
        .hiddenCount: "已隐藏 %d 张图片", .unhiddenCount: "已取消隐藏 %d 张图片",
        .deletedCount: "已删除 %d 张图片", .setHiddenOne: "已设为隐藏", .unsetHiddenOne: "已取消隐藏",
        .dateAll: "全部", .dateToday: "今天", .dateWeek: "本周", .dateMonth: "本月",
        .dateYear: "今年", .dateCustom: "自定义",
        .catAll: "全部", .catFavorites: "收藏", .catVideos: "视频", .catScreenshots: "截图",
        .catLivePhoto: "Live Photo", .catLocation: "有位置",
        .sortNewest: "最新优先", .sortOldest: "最早优先",
        .sortResHigh: "分辨率从高到低", .sortResLow: "分辨率从低到高", .sortName: "文件名 A-Z",
        .libVisible: "可见", .libHidden: "已隐藏", .libAll: "全部",
        .filename: "文件名", .resolution: "分辨率", .aspectRatio: "宽高比",
        .fileSize: "文件大小", .mediaType: "媒体类型", .source: "来源", .duration: "时长",
        .created: "创建时间", .modified: "修改时间", .location: "位置",
        .favorite: "收藏", .hidden: "隐藏", .importedAt: "导入时间", .shotAt: "拍摄时间",
        .direction: "方向", .unknown: "未知", .calculating: "计算中…",
        .retry: "重试", .bsideLoadFailed: "页面加载失败",
        .noSearchResultsWithQuery: "未找到匹配「%@」的图片",
        .limitedLibraryHint: "当前仅可访问部分照片，可添加更多授权。",
        .limitedLibraryManage: "管理授权照片",
        .exportHeader: "📷 Vivide 图片信息", .exportDivider: "━━━━━━━━━━━━━━━━",
        .exportFromVivide: "— 来自 Vivide",
        .mediaImage: "图片", .mediaVideo: "视频", .mediaAudio: "音频", .mediaUnknown: "未知",
        .subtypePanorama: "全景", .subtypeHDR: "HDR", .subtypeScreenshot: "截图",
        .subtypeLivePhoto: "Live Photo", .subtypeDepthEffect: "人像景深",
        .sourceUserLibrary: "用户相册", .sourceCloudShared: "iCloud 共享",
        .sourceITunes: "iTunes 同步", .sourceOther: "其他",
        .exifMake: "相机品牌", .exifModel: "相机型号", .exifSoftware: "软件", .exifLens: "镜头",
        .exifFocalLength: "焦距", .exifAperture: "光圈", .exifISO: "ISO", .exifShutter: "快门",
        .exifFlash: "闪光灯", .exifWhiteBalance: "白平衡", .exifColorSpace: "色彩空间",
        .exifWidth: "EXIF 宽度", .exifHeight: "EXIF 高度",
        .exifLatitude: "GPS 纬度", .exifLongitude: "GPS 经度", .exifAltitude: "海拔",
        .exifFlashOff: "未闪光", .exifFlashOn: "已闪光", .exifWbAuto: "自动", .exifWbManual: "手动",
        .exifOrientationNormal: "正常", .exifOrientation180: "旋转 180°",
        .exifOrientationCW90: "顺时针 90°", .exifOrientationCCW90: "逆时针 90°",
        .exifOrientationUnknown: "方向 %d", .exifExposureSeconds: "%.1f 秒", .exifExposureFraction: "1/%d 秒"
    ]

    private static let enStrings: [L10nKey: String] = [
        .tabAlbum: "Album", .tabLocal: "Local", .tabSettings: "Settings",
        .appName: "Vivide", .selectPhotos: "Select Photos",
        .settingsTitle: "Settings", .settingsLanguage: "Language", .settingsAppearance: "Appearance",
        .settingsLocalLibrary: "Local Library", .settingsShowHiddenPhotos: "Show Hidden Photos",
        .settingsShowHiddenPhotosHint: "When enabled, hidden photos appear in the default local library list",
        .settingsAbout: "About", .settingsVersion: "Version",
        .settingsDescription: "A graceful photo info explorer",
        .settingsBSideTitle: "Discover", .settingsBSideHint: "Open the web experience in the app.",
        .settingsBSideOpen: "Open Web Version", .bsideClose: "Back to App",
        .settingsLegal: "Legal", .userAgreement: "User Agreement", .privacyPolicy: "Privacy Policy",
        .languageSystem: "System", .languageZhHans: "简体中文", .languageEnglish: "English",
        .appearanceSystem: "System", .appearanceLight: "Light", .appearanceDark: "Dark",
        .permissionExploreTitle: "Explore Your Album",
        .permissionExploreMessage: "Vivide needs photo access to show details and save copies locally.",
        .permissionAllow: "Allow Photo Access",
        .permissionDeniedTitle: "Photo Access Denied",
        .permissionDeniedMessage: "Enable photo access in Settings → Privacy → Photos.",
        .permissionOpenSettings: "Open Settings",
        .myAlbum: "My Album", .reset: "Reset", .localCount: "Local",
        .loadingAlbum: "Loading album…", .noPhotos: "No photos or videos in album",
        .noSearchResults: "No matching photos", .noFilterResults: "No photos match filters",
        .clearFilters: "Clear Filters", .totalPhotos: "%d items total",
        .showingPhotos: "Showing %d / %d", .selectToImport: "Tap media to import",
        .albumOverview: "Overview", .filterShowing: "Filtered %d",
        .searchPlaceholder: "Search name or type…", .sortLabel: "Sort",
        .importSelect: "Select to Import", .importFiltered: "Import Filtered Results",
        .importFolderLabel: "Import to Folder", .folderAll: "All",
        .newFolder: "New", .newFolderTitle: "New Folder",
        .newFolderPlaceholder: "Folder name", .createFolder: "Create",
        .folderNameEmpty: "Please enter a folder name", .folderNameExists: "Folder name already exists",
        .localFolderFilter: "Folders", .storageFolder: "Storage Folder",
        .manageFolders: "Manage", .renameFolder: "Rename", .deleteFolder: "Delete Folder",
        .renameFolderTitle: "Rename Folder", .save: "Save",
        .deleteFolderTitle: "Delete Folder?",
        .deleteFolderMessage: "\"%@\" has %d photos. Move them to All, or delete everything.",
        .deleteEmptyFolderMessage: "Delete folder \"%@\"?",
        .moveToAll: "Move to All", .deleteFolderAndPhotos: "Delete Folder & Photos",
        .folderRenamed: "Folder renamed", .folderDeleted: "Folder deleted",
        .noCustomFolders: "No custom folders yet", .folderPhotoCount: "%d photos",
        .copyInfo: "Copy Info", .shareInfo: "Share Info", .copied: "Copied to clipboard",
        .photoDetail: "Photo Details", .basicInfo: "Basic Info", .captureInfo: "Capture Info",
        .exifInfo: "EXIF", .specialTags: "Tags", .localInfo: "Local Info",
        .loadingEXIF: "Reading EXIF…", .localPhoto: "Local Photo",
        .deleteLocalTitle: "Delete local copy?",
        .deleteLocalMessage: "This only removes the app copy, not the original in Photos.",
        .delete: "Delete", .cancel: "Cancel", .done: "Done", .manage: "Manage",
        .selectAll: "Select All", .deselectAll: "Deselect All", .selectedCount: "%d selected",
        .importToLocal: "Import (%d)", .importing: "Importing…",
        .hide: "Hide", .unhide: "Unhide", .deleteSelected: "Delete (%d)",
        .setHidden: "Hide", .unsetHidden: "Unhide", .hiddenLabel: "Hidden",
        .yes: "Yes", .no: "No",
        .savedLocally: "Saved in App", .localLibrarySummary: "%d photos · %@",
        .localEmpty: "Local library is empty",
        .localEmptyHint: "Select photos in Album tab to import locally",
        .noHiddenPhotos: "No hidden photos", .noVisiblePhotos: "No visible photos",
        .hiddenBadge: "Hidden", .folderEmptyPhotos: "No photos in this folder",
        .importSuccess: "Imported %d", .importSkipped: "Skipped %d (exists)",
        .importFailed: "Failed %d", .nothingToImport: "Nothing to import",
        .hiddenCount: "Hidden %d photos", .unhiddenCount: "Unhid %d photos",
        .deletedCount: "Deleted %d photos", .setHiddenOne: "Hidden", .unsetHiddenOne: "Unhidden",
        .dateAll: "All", .dateToday: "Today", .dateWeek: "This Week", .dateMonth: "This Month",
        .dateYear: "This Year", .dateCustom: "Custom",
        .catAll: "All", .catFavorites: "Favorites", .catVideos: "Videos", .catScreenshots: "Screenshots",
        .catLivePhoto: "Live Photo", .catLocation: "With Location",
        .sortNewest: "Newest First", .sortOldest: "Oldest First",
        .sortResHigh: "Highest Resolution", .sortResLow: "Lowest Resolution", .sortName: "Name A-Z",
        .libVisible: "Visible", .libHidden: "Hidden", .libAll: "All",
        .filename: "Filename", .resolution: "Resolution", .aspectRatio: "Aspect Ratio",
        .fileSize: "File Size", .mediaType: "Media Type", .source: "Source", .duration: "Duration",
        .created: "Created", .modified: "Modified", .location: "Location",
        .favorite: "Favorite", .hidden: "Hidden", .importedAt: "Imported", .shotAt: "Taken",
        .direction: "Orientation", .unknown: "Unknown", .calculating: "Calculating…",
        .retry: "Retry", .bsideLoadFailed: "Failed to load page",
        .noSearchResultsWithQuery: "No photos matching \"%@\"",
        .limitedLibraryHint: "You granted access to selected photos only. You can add more.",
        .limitedLibraryManage: "Manage Photo Access",
        .exportHeader: "📷 Vivide Photo Info", .exportDivider: "━━━━━━━━━━━━━━━━",
        .exportFromVivide: "— From Vivide",
        .mediaImage: "Image", .mediaVideo: "Video", .mediaAudio: "Audio", .mediaUnknown: "Unknown",
        .subtypePanorama: "Panorama", .subtypeHDR: "HDR", .subtypeScreenshot: "Screenshot",
        .subtypeLivePhoto: "Live Photo", .subtypeDepthEffect: "Portrait Depth",
        .sourceUserLibrary: "User Library", .sourceCloudShared: "iCloud Shared",
        .sourceITunes: "iTunes Sync", .sourceOther: "Other",
        .exifMake: "Camera Make", .exifModel: "Camera Model", .exifSoftware: "Software", .exifLens: "Lens",
        .exifFocalLength: "Focal Length", .exifAperture: "Aperture", .exifISO: "ISO", .exifShutter: "Shutter",
        .exifFlash: "Flash", .exifWhiteBalance: "White Balance", .exifColorSpace: "Color Space",
        .exifWidth: "EXIF Width", .exifHeight: "EXIF Height",
        .exifLatitude: "GPS Latitude", .exifLongitude: "GPS Longitude", .exifAltitude: "Altitude",
        .exifFlashOff: "No Flash", .exifFlashOn: "Flash Fired", .exifWbAuto: "Auto", .exifWbManual: "Manual",
        .exifOrientationNormal: "Normal", .exifOrientation180: "Rotated 180°",
        .exifOrientationCW90: "90° Clockwise", .exifOrientationCCW90: "90° Counter-clockwise",
        .exifOrientationUnknown: "Orientation %d", .exifExposureSeconds: "%.1f s", .exifExposureFraction: "1/%d s"
    ]
}

extension AppSettings {
    func format(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: args)
    }

    func dateFilterTitle(_ filter: DateFilter) -> String {
        switch filter {
        case .all: return t(.dateAll)
        case .today: return t(.dateToday)
        case .thisWeek: return t(.dateWeek)
        case .thisMonth: return t(.dateMonth)
        case .thisYear: return t(.dateYear)
        case .custom: return t(.dateCustom)
        }
    }

    func categoryTitle(_ filter: PhotoCategoryFilter) -> String {
        switch filter {
        case .all: return t(.catAll)
        case .favorites: return t(.catFavorites)
        case .videos: return t(.catVideos)
        case .screenshots: return t(.catScreenshots)
        case .livePhoto: return t(.catLivePhoto)
        case .withLocation: return t(.catLocation)
        }
    }

    func sortTitle(_ option: PhotoSortOption) -> String {
        switch option {
        case .dateNewest: return t(.sortNewest)
        case .dateOldest: return t(.sortOldest)
        case .resolutionLargest: return t(.sortResHigh)
        case .resolutionSmallest: return t(.sortResLow)
        case .nameAZ: return t(.sortName)
        }
    }

    var listSeparator: String {
        language.l10nCode.hasPrefix("zh") ? "、" : ", "
    }

    func mediaKindTitle(_ kind: PhotoMediaKind) -> String {
        kind.localizedTitle(languageCode: language.l10nCode)
    }

    func subtypeTitle(_ tag: PhotoSubtypeTag) -> String {
        tag.localizedTitle(languageCode: language.l10nCode)
    }

    func sourceKindTitle(_ kind: PhotoSourceKind) -> String {
        kind.localizedTitle(languageCode: language.l10nCode)
    }

    static func resolvedL10nCode() -> String {
        let stored = UserDefaults.standard.string(forKey: "vivide_language") ?? ""
        let language = AppLanguage(rawValue: stored) ?? .system
        return language.l10nCode
    }

    static func resolvedLocale() -> Locale {
        let stored = UserDefaults.standard.string(forKey: "vivide_language") ?? ""
        let language = AppLanguage(rawValue: stored) ?? .system
        return language.locale
    }
}
