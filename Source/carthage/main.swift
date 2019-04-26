import CarthageKit
import Commandant
import Foundation
import ReactiveSwift
import ReactiveTask
import Result

setlinebuf(stdout)

guard ensureGitVersion().first()?.value == true else {
	fputs("Carthage requires git \(carthageRequiredGitVersion) or later.\n", stderr)
	exit(EXIT_FAILURE)
}

var versionUpdateTips: () -> Void = { }
DispatchQueue.global(qos: .background).async {
    if let remoteVersion = remoteVersion(), CarthageKitVersion.current.value < remoteVersion {
        versionUpdateTips = {
            fputs("Please update to the latest Carthage version: \(remoteVersion). You currently are on \(CarthageKitVersion.current.value)" + "\n", stderr)
        }
    }
}

CCon.readConfig()

var golbalColorOption: ColorOptions? {
    didSet {
        guard let value = golbalColorOption else { return }
        
        CCon.formatHandler = { raw, style -> String in
            switch style {
            case .quote: return value.formatting.quote(raw)
            case .path: return value.formatting.path(raw)
            case .projectName: return value.formatting.projectName(raw)
            }
        }
        
        let prefix = value.formatting.bulletin("*** ")
        CCon.logHandler = { message in
            carthage.println("\(prefix)\(message)")
        }
    }
}

let start = CFAbsoluteTimeGetCurrent()
atexit {
    CCon.generateCompileFilesPath()
    let end = CFAbsoluteTimeGetCurrent()
    let cost = end - start
    let time = String(format: "%.2f", cost)
    guard let t = golbalColorOption?.formatting.path("\(time)s") else { return }
    CCon.logHandler("Done, time cost: \(t) seconds")
    versionUpdateTips()
}

if let carthagePath = Bundle.main.executablePath {
	setenv("CARTHAGE_PATH", carthagePath, 0)
}

let registry = CommandRegistry<CarthageError>()
registry.register(ArchiveCommand())
registry.register(BootstrapCommand())
registry.register(BuildCommand())
registry.register(CheckoutCommand())
registry.register(CopyFrameworksCommand())
registry.register(FetchCommand())
registry.register(OutdatedCommand())
registry.register(UpdateCommand())
registry.register(ValidateCommand())
registry.register(VersionCommand())

let helpCommand = HelpCommand(registry: registry)
registry.register(helpCommand)

registry.main(defaultVerb: helpCommand.verb) { error in
	fputs(error.description + "\n", stderr)
}
