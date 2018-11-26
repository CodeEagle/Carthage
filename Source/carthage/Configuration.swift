import CarthageKit
import Commandant
import Foundation
import Result
import ReactiveSwift

// swiftlint:disable missing_docs

public struct ConfigurationCommand: CommandProtocol {

	public let verb = "config-init"
	public let function = "Generate configuration file for carthage"

	public func run(_ options: NoOptions<CarthageError>) -> Result<(), CarthageError> {
		CCon.generateNewConfig()
		return .success(())
	}
}
