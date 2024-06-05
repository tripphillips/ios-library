/* Copyright Airship and Contributors */

import Foundation
import os

///
/// Airship logger.
///
/// - Note: For internal use only. :nodoc:
public class AirshipLogger {

    static var logLevel: AirshipLogLevel = .error
    static var logPrivacyLevel: AirshipLogPrivacyLevel = .private

    static var logHandler: AirshipLogHandler = DefaultLogHandler()

    public static func trace(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.verbose,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func debug(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.debug,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func info(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.info,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func importantInfo(
        _ message: String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.info,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message,
            fileID: fileID,
            line: line,
            function: function,
            skipLogLevelCheck: true
        )
    }

    public static func warn(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.warn,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func error(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.error,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func impError(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.error,
            logPrivacyLevel: AirshipLogger.logPrivacyLevel,
            message: "🚨Airship Implementation Error🚨: \(message())",
            fileID: fileID,
            line: line,
            function: function
        )
    }

    static func log(
        logLevel: AirshipLogLevel,
        logPrivacyLevel: AirshipLogPrivacyLevel,
        message: @autoclosure () -> String,
        fileID: String,
        line: UInt,
        function: String,
        skipLogLevelCheck: Bool = false
    ) {

        guard self.logLevel != .none, self.logLevel != .undefined else {
            return
        }

        if skipLogLevelCheck || self.logLevel.rawValue >= logLevel.rawValue {
            logHandler.log(
                logLevel: logLevel,
                logPrivacyLevel: logPrivacyLevel,
                message: message(),
                fileID: fileID,
                line: line,
                function: function
            )
        }
    }
}
