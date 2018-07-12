//
//  Configuration.swift
//  carthage
//
//  Created by Lincoln Law on 2018/1/4.
//  Copyright © 2018年 Carthage. All rights reserved.
//

import Foundation
import XCDBLD
import PrettyColors
/// Carthage Configuration
public let CCon = Configuration.shared
public final class Configuration {
	
	public static let shared = Configuration()
	/// The Xcode configuration to build.
	public var configuration: String = "Release"
	/// The platforms to build for.
	public var platforms: Set<Platform> = Set(Platform.supportedPlatforms)
	/// Rebuild even if cached builds exist.
	public var isEnableCacheBuilds: Bool = false
	public var isEnableGenerateFastBootXCConfig: Bool = false
	public var isEnableNewResolver: Bool = false
	public var isEnableVerbose: Bool = false
	public var isUsingSSH: Bool = false
	public var isUsingSubmodules: Bool = false
	public var skippableDependencies: [SkippableDepency] = []
	public var overridableDependencies: [String : Dependency] = [:]
	public var totalDependencies: [String : Dependency] = [:]
	public var dependencyBuildPath: [Dependency : String] = [:]
	public var fastBootXCConfigFolder: URL?
	public var excludePaths: Set<String> = []
	public var formatHandler: (String, LogStyle) -> String = { raw, _ in return raw }
	public var logHandler: (String) -> Void = { _ in }
	private var currentDependency: Dependency? = nil
	private var buildedPathDependency: Set<Dependency> = []
	public var logRecords: Set<String> = []
	
	private init() { }
	
	public func readConfig() {
		guard let pwd = ProcessInfo.processInfo.environment["PWD"] else { return }
		let privateCartfilePath = "\(pwd)/\(Constants.Project.privateCartfilePath)"
		guard let content = try? String.init(contentsOfFile: privateCartfilePath) else { return }
		
		content.enumerateLines { (line, ioStop) in
			let trimLine = line.trim
			if trimLine.hasPrefix(Key.override) {
				self.readOverridableDependency(from: trimLine)
			} else if trimLine.hasPrefix(Key.excludePath) {
				self.excludePaths.insert(trimLine.replacingOccurrences(of: Key.excludePath.rawValue, with: "").trim)
			} else if trimLine.hasPrefix(Key.skip) {
				self.readSkippableDependency(from: trimLine)
			} else if trimLine.hasPrefix(Key.platforms) {
				self.readPlatform(from: trimLine)
			} else if trimLine.hasPrefix(Key.configuration) {
				self.readConfiguration(from: trimLine)
			} else if trimLine.hasPrefix(Key.cacheBuilds) {
				self.isEnableCacheBuilds = Key.cacheBuilds.bool(from: trimLine)
			} else if trimLine.hasPrefix(Key.newResolver) {
				self.isEnableNewResolver = Key.newResolver.bool(from: trimLine)
			} else if trimLine.hasPrefix(Key.verbose) {
				self.isEnableVerbose = Key.verbose.bool(from: trimLine)
			} else if trimLine.hasPrefix(Key.useSubmodules) {
				self.isUsingSubmodules = Key.useSubmodules.bool(from: trimLine)
			} else if trimLine.hasPrefix(Key.generateFastBootXCConfig) {
				self.isEnableGenerateFastBootXCConfig = Key.generateFastBootXCConfig.bool(from: trimLine)
			}
		}
	}
	
	private func readPlatform(from line: String) {
		let trimLine = line.replacingOccurrences(of: Key.platforms.rawValue, with: "").trimCommentInLine.trim
		if trimLine.isEmpty { return }
		let preferPlatforms = trimLine.components(separatedBy: ",").compactMap({ Platform.from($0) })
		platforms = Set(preferPlatforms)
	}
	
	private func readConfiguration(from line: String) {
		var trimLine = line.replacingOccurrences(of: Key.configuration.rawValue, with: "").trimCommentInLine.trim
		if ["release", "debug"].contains(trimLine.lowercased()) {
			trimLine = trimLine.capitalized
		}
		configuration = trimLine
	}
	
	private func readSkippableDependency(from line: String) {
		let trimLine = line.replacingOccurrences(of: Key.skip.rawValue, with: "").trimCommentInLine.trim
		let components = trimLine.components(separatedBy: ",")
		guard let name = components[c_safe: 0]?.trim else { return }
		let workspaceOrProject = components[c_safe: 1]?.trim
		let scheme = components[c_safe: 2]?.trim
		let dependency = SkippableDepency(name: name, scheme: scheme, workspaceOrProject: workspaceOrProject)
		skippableDependencies.append(dependency)
	}
	
	private func readOverridableDependency(from line: String) {
		let components = line.replacingOccurrences(of: Key.override.rawValue, with: "").trimCommentInLine.trim.components(separatedBy: ",")
		guard let name = components[c_safe: 0]?.trim.lowercased(), let path = components[c_safe: 1]?.trim else { return }
		let denpendency = Dependency.git(GitURL(path))
		overridableDependencies[name] = denpendency
	}
	
	public func runOptions() -> String {

		let configurationString = "--configuration \(configuration)"
		let platformsString =  " --platform \(platforms.compactMap({ Optional($0.rawValue) }).joined(separator: " "))"
		let cacheBuildString =  isEnableCacheBuilds ? " --cache-builds" : ""
		let newResolverString =  isEnableNewResolver ? " --new-resolver" : ""
		let verboseString = isEnableVerbose ? " --verbose" : ""
		let sshString = isUsingSSH ? " --use-ssh" : ""
		let submodulesString = isUsingSSH ? " --use-submodules" : ""
		let generateXCConfig = isEnableGenerateFastBootXCConfig ? " generate-fast-boot-xcconfig" : ""

		return "\(configurationString)\(cacheBuildString)\(platformsString)\(newResolverString)\(verboseString)\(sshString)\(submodulesString)\(generateXCConfig)"
	}
	
	private func dependencyFrom(url: URL) -> Dependency? {
		let raw = url.absoluteString
		for (dependency, _) in dependencyBuildPath {
			let target = "/Checkouts/\(dependency.name)/"
			guard raw.contains(target) else { continue }
			return dependency
		}
		return nil
	}
	
	public func startBuildProject(_ url: URL) {
		guard let dependency = dependencyFrom(url: url) else { return }
		if let old = currentDependency {
			if old != dependency {
				generateFileLogForCurrentDependency(old)
			}
			currentDependency = dependency
		} else {
			currentDependency = dependency
		}
	}
	
	public func generateFileLogForCurrentDependency(_ dependency: Dependency) {
		if buildedPathDependency.contains(dependency) { return }
		guard let buildPath = dependencyBuildPath[dependency] else { return }
		guard isEnableGenerateFastBootXCConfig, let baseURL = fastBootXCConfigFolder, platforms.contains(.iOS) else { return }
		buildedPathDependency.insert(dependency)
		let outputFolder = baseURL.absoluteString
		if FileManager.default.fileExists(atPath: outputFolder) == false {
			try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
		}
		let rawSuffix = "rawFilelist"
		let lines = findOFiles(in: buildPath).joined(separator: "\n").trimmingCharacters(in: .newlines).data(using: .utf8)
		let url = baseURL.appendingPathComponent("\(dependency.name).\(rawSuffix)", isDirectory: false)
		try? lines?.write(to: url)
	}
	
	public func generateCompileFilesPath() {
		guard isEnableGenerateFastBootXCConfig, let baseURL = fastBootXCConfigFolder, platforms.contains(.iOS) else { return }
		let outputFolder = baseURL.absoluteString
		if FileManager.default.fileExists(atPath: outputFolder) == false {
			try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
		}
		let rawSuffix = "rawFilelist"
		for (dependency, _) in dependencyBuildPath {
			generateFileLogForCurrentDependency(dependency)
		}
		let folderPath = outputFolder.replacingOccurrences(of: "file://", with: "")
		guard let items = try? FileManager.default.contentsOfDirectory(atPath: folderPath) else { return }
		let archs: [Arch] = [.armv7, .arm64, .i386, .x86_64]
		var archLines: [Arch : [String]] = [:]
		for item in items {
			guard item.hasSuffix(".\(rawSuffix)") else { continue }
			let url = baseURL.appendingPathComponent(item, isDirectory: false)
			guard let content = try? String(contentsOf: url) else { continue }
			var duplicateName: [Arch : Set<String>] = [:]
			content.enumerateLines(invoking: { (line, _) in
				for arch in archs {
					guard line.contains("/\(arch.rawValue)/") else { continue }
					guard self.excludeThis(line) == false else { continue }
					let lastPart = (line as NSString).lastPathComponent
					var archSet = duplicateName[arch] ?? []
					if archSet.contains(lastPart) { continue }
					archSet.insert(lastPart)
					duplicateName[arch] = archSet
					var lines = archLines[arch] ?? []
					lines.append(line)
					archLines[arch] = lines
					break
				}
			})
		}
		for (arch, lines) in archLines {
			let content = lines.joined(separator: "\n").trimmingCharacters(in: .newlines).data(using: .utf8)
			let url = baseURL.appendingPathComponent("\(arch.rawValue).filelist", isDirectory: false)
			try? content?.write(to: url)
		}
		
		let baseXcconfigPath = baseURL.appendingPathComponent("Base.xcconfig", isDirectory: false)
		let debugXcconfigPath = baseURL.appendingPathComponent("Debug.xcconfig", isDirectory: false)
		let ReleaseXcconfigPath = baseURL.appendingPathComponent("Release.xcconfig", isDirectory: false)
		
		let baseXcconfig =
"""
FRAMEWORK_SEARCH_PATHS = $(inherited) $(PROJECT_DIR)/Carthage/Build/iOS
LD_RUNPATH_SEARCH_PATHS = $(inherited) @loader_path/Frameworks
OTHER_LDFLAGS = $(inherited) -fprofile-instr-generate
"""
		let debugXcconfig =
"""
#include "Release.xcconfig"
OTHER_LDFLAGS[arch=arm64] = $(inherited) -filelist $(SRCROOT)/Carthage/FastBoot/arm64.filelist
OTHER_LDFLAGS[arch=armv7] = $(inherited) -filelist $(SRCROOT)/Carthage/FastBoot/armv7.filelist
"""
		let releaseXcconfig =
"""
#include "Base.xcconfig"
OTHER_LDFLAGS[arch=arm64] = $(inherited) -filelist $(SRCROOT)/Carthage/FastBoot/arm64.filelist
OTHER_LDFLAGS[arch=armv7] = $(inherited) -filelist $(SRCROOT)/Carthage/FastBoot/armv7.filelist
"""
		try? baseXcconfig.data(using: .utf8)?.write(to: baseXcconfigPath)
		try? debugXcconfig.data(using: .utf8)?.write(to: debugXcconfigPath)
		try? releaseXcconfig.data(using: .utf8)?.write(to: ReleaseXcconfigPath)
	}
	
	private func excludeThis(_ line: String) -> Bool {
		for item in excludePaths {
			if line.contains(item) { return true }
		}
		return false
	}
	
	private func findOFiles(in path: String) -> [String] {
		var total: [String] = []
		if let items = try? FileManager.default.contentsOfDirectory(atPath: path) {
			var isDir = ObjCBool(false)
			for item in items {
				isDir = ObjCBool(false)
				guard item != ".DS_Store" else { continue }
				let itemPath = "\(path)/\(item)"
				if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir) {
					if isDir.boolValue == true {
						total += findOFiles(in: itemPath)
					} else {
						guard item.hasSuffix(".o") else { continue }
						total.append(itemPath)
					}
				}
			}
		}
		return total
	}
}
extension Configuration {
	func uniqueDependency(for dependency: Dependency) -> Dependency {
		var value = dependency
		let name = dependency.name
		if let old = totalDependencies[name] {
			if old.isLocalProject == false, dependency.isLocalProject == true {
				totalDependencies[name] = dependency
			} else {
				value = old
			}
		} else {
			totalDependencies[name] = dependency
		}
		return value
	}
	
	func replaceOverrideDependencies(for dependencies: UnsafeMutablePointer<[Dependency: VersionSpecifier]>){
		let value = dependencies.pointee
		var copyDependencies = value
		let formatter = CCon.formatHandler
		let log = CCon.logHandler
		for (dependency, version) in value {
			let name = dependency.name.lowercased()
			if let overrideRepo = overridableDependencies[name], overrideRepo != dependency {
				copyDependencies[dependency] = nil
				copyDependencies[overrideRepo] = version
				let name = formatter(name, .projectName)
				let url = formatter(overrideRepo.gitURL(preferHTTPS: true)?.description ?? "", .path)
				let message = "Override \(name) to \(url)"
				if CCon.logRecords.contains(message) == false {
					CCon.logRecords.insert(message)
					log(message)
				}
			}
		}
		dependencies.pointee = copyDependencies
	}
}
extension Configuration: CustomStringConvertible {
	public var description: String {
		return
"""
  Configuration {
	isEnableCacheBuilds: \(isEnableCacheBuilds),
	isEnableGenerateFastBootXCConfig: \(isEnableGenerateFastBootXCConfig),
	configuration: \(configuration),
	isEnableNewResolver: \(isEnableNewResolver),
	isEnableVerbose: \(isEnableVerbose),
	isUsingSSH: \(isUsingSSH)
	isUsingSubmodules: \(isUsingSubmodules)
	platforms:\(platforms),
	skippableDepencies:\(skippableDependencies),
	overridableDepencies:\(overridableDependencies)
  }
"""
	}
}
/*
#cache-builds: true/false, default false
#verbose: true/false, default false
#configuration: Release/Debug or other
#new-resolver: true/false, default false
#use-ssh: true/false, default false
#use-submodules: true/false, default false
#platform: all/macOS/iOS/watchOS/tvOS
#skip Alamofire,Alamofire.xcworkspace,Alamofire iOS
#override Alamofire,../Alamofire
#generate-fast-boot-xcconfig: true/false, default false
#exclude-path: string, exclude xcconfig arch o file path contain this string
*/
extension Configuration {
	public enum Key: String {
		case verbose = "#verbose:"
		case configuration = "#configuration:"
		case newResolver = "#new-resolver:"
		case useSSH = "#use-ssh:"
		case useSubmodules = "#use-submodules:"
		case cacheBuilds = "#cache-builds:"
		case platforms = "#platforms:"
		case skip = "#skip:"
		case override = "#override:"
		case generateFastBootXCConfig = "#generate-fast-boot-xcconfig:"
		case excludePath = "#exclude-path:"
		
		func bool(from line: String) -> Bool {
			let trimLine = line.replacingOccurrences(of: rawValue, with: "").trimCommentInLine.trim.lowercased()
			return trimLine == "true"
		}
	}
	
	public struct SkippableDepency {
		public let name: String
		public let scheme: String?
		public let workspaceOrProject: String?
	}
	
	public enum Arch: String {
		case armv7, arm64, i386, x86_64
	}
	
	public enum LogStyle {
		case quote, path, projectName
	}
}


extension Platform {
	static func from(_ raw: String) -> Platform? {
		let lowercasedRaw = raw.lowercased()
		let mac = ["osx", "mac", "macos"]
		switch lowercasedRaw {
		case "ios": return .iOS
		case "watchos": return .watchOS
		case "tvos": return .tvOS
		default:
			if mac.contains(lowercasedRaw) { return .macOS }
			return nil
		}
	}
}
extension Array {
	subscript(c_safe index: Int) -> Element? {
		return indices ~= index ? self[index] : nil
	}
}
extension String {
	var trimCommentInLine: String {
		var target = self
		let components = target.split(separator: "#")
		if let value = components.first {
			target = String(value)
		}
		return target
	}
	var trim: String { return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
	func hasPrefix<T: RawRepresentable>(_ key: T) -> Bool where T.RawValue == String {
		return hasPrefix(key.rawValue)
	}
}

extension Dependency {
	public var isLocalProject: Bool {
		switch self {
		case .git(let url):
			let urlString = url.urlString
			if urlString.hasPrefix("file://")
				|| urlString.hasPrefix("/") // "/path/to/..."
				|| urlString.hasPrefix(".") // "./path/to/...", "../path/to/..."
				|| urlString.hasPrefix("~") // "~/path/to/..."
				|| !urlString.contains(":") // "path/to/..." with avoiding "git@github.com:owner/name"
			{ return true }
			return false
		default: return false
		}
	}
}
