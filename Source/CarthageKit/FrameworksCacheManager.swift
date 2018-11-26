import Foundation
import XCDBLD

/// Manager frameworks
public final class FrameworksCacheManager {
	private static let shared = FrameworksCacheManager()
	private init() { }

	private let location = Constants.Dependency.frameworksCacheURL
	private var bcSymbolMapsForFramework: [String: Set<URL>] = [:]
	private var platformNames: [String: String] = [
		"ios": "iphoneos",
		"macos": "",
		"watchos": "watchos",
		"tvos": "appletvos",
	]
}

extension FrameworksCacheManager {

	static func versionFile(for dependency: Dependency, version: PinnedVersion, platforms: Set<Platform>, targetCopyURL: URL) -> VersionFile? {
		let targetFolder = shared.location.appendingPathComponent(dependency.name).appendingPathComponent(version.commitish)
		let versionFileURL = targetFolder.appendingPathComponent(".\(dependency.name).\(VersionFile.pathExtension)")
		let fm = FileManager.default
		if let file = VersionFile(url: versionFileURL) {
			let compatible = platforms.filter { platform -> Bool in
				return file[platform]?.isEmpty == true
			}.isEmpty == true
			guard compatible else { return nil }

			// Copy VersionFile
			let u = targetCopyURL.appendingPathComponent(versionFileURL.lastPathComponent)
			try? fm.copyItem(at: versionFileURL, to: u, avoiding·rdar·32984063: true)

			for platform in platforms {
				let sourceURL = targetFolder.appendingPathComponent(platform.rawValue)
				let targetURL = targetCopyURL.appendingPathComponent(platform.rawValue)
				if fm.fileExists(atPath: targetURL.absoluteString) == false {
					try? fm.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
				}
				let folderPath = sourceURL.absoluteString.replacingOccurrences(of: "file://", with: "")
				let items = (try? fm.contentsOfDirectory(atPath: folderPath)) ?? []

				for item in items {
					let file = URL(fileURLWithPath: folderPath).appendingPathComponent(item)
					if item.hasSuffix("framework") {
						let target = targetURL.appendingPathComponent(file.lastPathComponent)
						fm.copyFolder(file, to: target)
					} else {
						try? fm.copyItem(at: file, to: targetURL, avoiding·rdar·32984063: true)
					}
				}
			}
			return file
		}
		return nil
	}

	static func add(bcSymbolMapsURL: URL, for frameowrk: URL) {
		let name = frameowrk.lastPathComponent
		var origin = shared.bcSymbolMapsForFramework[name] ?? []
		origin.insert(bcSymbolMapsURL)
		shared.bcSymbolMapsForFramework[name] = origin
	}

	static func copy(commitish: String, name: String, platformCaches: [String: [CachedFramework]], versionFileURL: URL, versionFile: VersionFile) {
		let targetFolder = shared.location.appendingPathComponent(name).appendingPathComponent(commitish)
		let versionFileToWriteURL = targetFolder.appendingPathComponent(versionFileURL.lastPathComponent)
		let fm = FileManager.default
		try? fm.removeItem(at: targetFolder)
		try? fm.createDirectory(at: targetFolder, withIntermediateDirectories: true, attributes: nil)

		_ = versionFile.write(to: versionFileToWriteURL)
		let buildFolder = versionFileURL.deletingLastPathComponent()
		for (key, values) in platformCaches {
			guard values.isEmpty == false else { continue }
			let targetLocation = targetFolder.appendingPathComponent(key)
			if fm.fileExists(atPath: targetLocation.absoluteString) == false {
				try? fm.createDirectory(at: targetLocation, withIntermediateDirectories: true, attributes: nil)
			}

			// Support Multiple Build
			if let p = Platform(rawValue: key), let frameworks = versionFile[p] {
				for f in frameworks {
					let fname = f.name
					let frameworkName = "\(fname).framework"
					let source = buildFolder.appendingPathComponent(key).appendingPathComponent(frameworkName)
					let target = targetLocation.appendingPathComponent(frameworkName)
					fm.copyFolder(source, to: target)

					let bcFiles = shared.bcSymbolMapsForFramework[frameworkName]?.filter { url -> Bool in
						if let platformName = shared.platformNames[key.lowercased()] {
							return url.absoluteString.contains(platformName)
						}
						return false
					}
					guard let files = bcFiles else { continue }
					for file in files {
						try? fm.copyItem(at: file, to: targetLocation, avoiding·rdar·32984063: true)
					}
				}
			}
		}
	}
}

extension FileManager {
	func copyFolder(_ folder: URL, to: URL) {
		let sourceRaw = folder.absoluteString.replacingOccurrences(of: "file://", with: "")
		let source = "\(sourceRaw.removingPercentEncoding ?? sourceRaw)"
		let targetRaw = to.absoluteString.replacingOccurrences(of: "file://", with: "")
		let target = "\(targetRaw.removingPercentEncoding ?? targetRaw)"
		let task = Process()
		task.environment = ProcessInfo().environment
		task.launchPath = "/bin/bash"
		task.arguments = ["-c", "cp -rf \(source) \(target)"]
		task.launch()
		task.waitUntilExit()
	}
}
