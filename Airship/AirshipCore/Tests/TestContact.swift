import Foundation
import Combine

@testable import AirshipCore

class TestContact: InternalAirshipContactProtocol, AirshipComponent, @unchecked Sendable {
    func getStableContactInfo() async -> StableContactInfo {
        return StableContactInfo(contactID: await getStableContactID(), namedUserID: namedUserID)
    }
    
    init() {}

    func registerEmail(_ address: String, options: AirshipCore.EmailRegistrationOptions) {

    }
    
    func registerSMS(_ msisdn: String, options: AirshipCore.SMSRegistrationOptions) {

    }
    
    func registerOpen(_ address: String, options: AirshipCore.OpenRegistrationOptions) {

    }
    
    var smsValidatorDelegate: (any AirshipCore.SMSValidatorDelegate)?
    
    func resend(_ channel: AirshipCore.ContactChannel) {

    }
    
    func disassociateChannel(_ channel: AirshipCore.ContactChannel) {

    }

    var contactChannelUpdates: AsyncStream<[ContactChannel]> = AsyncStream<[ContactChannel]>.init { _ in }
    
    var contactChannelPublisher: AnyPublisher<[AirshipCore.ContactChannel], Never> = Just([]).eraseToAnyPublisher()

    func associateChannel(_ channelID: String, type: AirshipCore.ChannelType) {

    }

    var SMSValidatorDelegate: SMSValidatorDelegate?
    func validateSMS(_ msisdn: String, sender: String) async throws -> Bool {
        true
    }

    func fetchAssociatedChannelsList() async -> [AssociatedChannel]? {
        return nil
    }

    func notifyRemoteLogin() {
    }

    var contactIDInfo: AirshipCore.ContactIDInfo? = nil

    let contactIDUpdatesSubject = PassthroughSubject<ContactIDInfo, Never>()
    var contactIDUpdates: AnyPublisher<ContactIDInfo, Never>  {
        contactIDUpdatesSubject.eraseToAnyPublisher()
    }

    var contactID: String? = nil

    var authTokenProvider: AuthTokenProvider = TestAuthTokenProvider { id in
        return ""
    }

    func getStableContactID() async -> String {
        return contactID ?? ""
    }

    @objc
    public static let contactConflictEvent = NSNotification.Name(
        "com.urbanairship.contact_conflict"
    )

    @objc
    public static let contactConflictEventKey = "event"

    @objc
    public static let maxNamedUserIDLength = 128


    private let conflictEventSubject = PassthroughSubject<ContactConflictEvent, Never>()
    public var conflictEventPublisher: AnyPublisher<ContactConflictEvent, Never> {
        conflictEventSubject.eraseToAnyPublisher()
    }

    private let namedUserUpdatesSubject = PassthroughSubject<String?, Never>()
    public var namedUserIDPublisher: AnyPublisher<String?, Never> {
        namedUserUpdatesSubject
            .prepend(namedUserID)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var subscriptionListEdits: AnyPublisher<AirshipCore.ScopedSubscriptionListEdit, Never> {
        subscriptionListEditsSubject.eraseToAnyPublisher()
    }
    private let subscriptionListEditsSubject = PassthroughSubject<ScopedSubscriptionListEdit, Never>()

    public func _getNamedUserID() async -> String? {
        return self.namedUserID
    }

    public var isComponentEnabled: Bool = true

    public var namedUserID: String?

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    @objc
    public var tagGroupEditor: TagGroupsEditor?

    @objc
    public var attributeEditor: AttributesEditor?

    public var subscriptionListEditor: ScopedSubscriptionListEditor?

    public func identify(_ namedUserID: String) {
        self.namedUserID = namedUserID
    }

    public func reset() {
        self.namedUserID = nil
    }

    public func editTagGroups() -> TagGroupsEditor {
        return tagGroupEditor!
    }

    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }

    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    public func editSubscriptionLists() -> ScopedSubscriptionListEditor {
        return subscriptionListEditor!
    }

    public func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    public func fetchSubscriptionLists() async throws ->  [String: [ChannelScope]] {
        return [:]
    }

    public func _fetchSubscriptionLists() async throws ->  [String: ChannelScopes] {
        return [:]
    }
}
