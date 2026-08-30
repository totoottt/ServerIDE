import XCTest
@testable import ServerIDE

final class DeveloperToolsTests: XCTestCase {
    @MainActor
    func testTerminalResumeDoesNotCreateExtraTabs() {
        let workspace = TerminalWorkspace()
        let server = ServerProfile(name: "Test", host: "example.com", username: "test")
        workspace.resumeOrOpen(server)
        workspace.resumeOrOpen(server)
        XCTAssertEqual(workspace.sessions.count, 1)
        workspace.close(workspace.sessions[0].id)
        XCTAssertEqual(workspace.sessions.count, 0)
        XCTAssertNil(workspace.selected)
    }
    func testInstalledFilesFlags() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool, true)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSSupportsOpeningDocumentsInPlace") as? Bool, true)
    }
    func testIPAddressValidation() {
        XCTAssertTrue(IPLookupService.validAddress("1.1.1.1"))
        XCTAssertTrue(IPLookupService.validAddress("2001:db8::1"))
        for invalid in ["https://example.com", "1.2.3.999", "example.com", "", "1.1.1.1/json/"] {
            XCTAssertFalse(IPLookupService.validAddress(invalid))
        }
    }
    func testTerminalPreservesErrorOutputAndExitCode() {
        let marker = "__STATUS__="
        let result = SSHConnectionManager.parseTerminalOutput("permission denied\n__STATUS__=13\n", marker: marker)
        XCTAssertEqual(result.output, "permission denied")
        XCTAssertEqual(result.exitCode, 13)
    }
    func testCronAndHexTools() throws {
        XCTAssertEqual(try CronExpression(minute: "*/5", hour: "*", day: "*", month: "*", weekday: "1-5").value,
                       "*/5 * * * 1-5")
        XCTAssertThrowsError(try CronExpression(minute: "$(bad)", hour: "*", day: "*", month: "*", weekday: "*"))
        XCTAssertTrue(HexViewerView.render(Data([0x41, 0x00, 0x26])).contains("41 00 26"))
        XCTAssertTrue(HexViewerView.render(Data([0x41, 0x00, 0x26])).contains("|A.&|"))
    }
    func testSecretShareRoundTripAndWrongPassphrase() throws {
        let payload = try EncryptedSecretView.encrypt("سري / . ( ) &", passphrase: "correct horse battery staple")
        XCTAssertEqual(try EncryptedSecretView.decrypt(payload, passphrase: "correct horse battery staple"), "سري / . ( ) &")
        XCTAssertThrowsError(try EncryptedSecretView.decrypt(payload, passphrase: "wrong password value"))
    }
    func testLocalCommandsAndHiddenFiles() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = try LocalCommandEngine(root: root)
        _ = try engine.run("mkdir 'new folder'")
        _ = try engine.run("touch .hidden")
        XCTAssertFalse(try engine.run("ls").contains(".hidden"))
        XCTAssertTrue(try engine.run("ls -a").contains(".hidden"))
        _ = try engine.run("cd 'new folder'")
        XCTAssertEqual(try engine.run("pwd"), "/new folder")
        XCTAssertEqual(try engine.run("echo 'مرحبا بالعالم'"), "مرحبا بالعالم")
        XCTAssertThrowsError(try engine.run("cd ../.."))
        XCTAssertThrowsError(try engine.run("python3 file.py"))
    }
    func testLocalNoOverwriteAndRecoverableRemove() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = try LocalCommandEngine(root: root)
        _ = try engine.run("touch original")
        _ = try engine.run("cp original copy")
        XCTAssertThrowsError(try engine.run("cp original copy"))
        let reply = try engine.run("rm copy")
        XCTAssertTrue(reply.contains("/.Trash/"))
        XCTAssertTrue(try engine.run("ls -a .Trash").contains("copy"))
        XCTAssertThrowsError(try engine.run("rm /"))
    }
    func testLocalSymlinkCannotEscapeDocuments() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("outside"), withDestinationURL: root.deletingLastPathComponent())
        let engine = try LocalCommandEngine(root: root)
        XCTAssertThrowsError(try engine.run("cd outside"))
        XCTAssertThrowsError(try engine.resolve("outside/another-file"))
    }
    func testLocalCommandQuoting() throws {
        XCTAssertEqual(try LocalCommandEngine.arguments("echo \"a b\" 'c d'"), ["echo", "a b", "c d"])
        XCTAssertThrowsError(try LocalCommandEngine.arguments("echo 'unfinished"))
    }
    func testCPUCountersParsing() {
        let metrics = ServerMetricsService().parse("CPU\t40 100\nMEM\t100 200\n")
        XCTAssertEqual(metrics.cpuBusyTicks, 40)
        XCTAssertEqual(metrics.cpuTotalTicks, 100)
        XCTAssertEqual(metrics.memoryFraction, 0.5)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("ServerIDE-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    // This call site is intentionally async: the SDK-restricted enumerator must
    // stay inside the synchronous helper, not inside a Task/async function.
    func testFolderEnumerationFromAsyncContext() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try Data("hello".utf8).write(to: nested.appendingPathComponent("hello.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden"))
        let items = try LocalFilesStore.folderUploadItems(in: folder, maxFileBytes: 1024)
        XCTAssertEqual(Set(items.map { $0.1 }), Set(["nested", "nested/hello.txt", ".hidden"]))
        XCTAssertTrue(items.contains { $0.1 == "nested" && $0.2 })
        XCTAssertTrue(items.contains { $0.1 == "nested/hello.txt" && !$0.2 })
    }

    func testFolderEnumerationRejectsSymlink() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("original")
        try Data().write(to: target)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link"), withDestinationURL: target)
        XCTAssertThrowsError(try LocalFilesStore.folderUploadItems(in: folder, maxFileBytes: 1024))
    }

    func testFolderEnumerationRejectsOversizeFile() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(repeating: 0, count: 11).write(to: folder.appendingPathComponent("large.bin"))
        XCTAssertThrowsError(try LocalFilesStore.folderUploadItems(in: folder, maxFileBytes: 10))
    }

    func testFolderEnumerationRejectsTooManyEntries() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for index in 0..<201 {
            try Data().write(to: folder.appendingPathComponent("file-\(index)"))
        }
        XCTAssertThrowsError(try LocalFilesStore.folderUploadItems(in: folder, maxFileBytes: 1024))
    }

    func testOldServerProfileMigration() throws {
        let json = """
        {"id":"DDC80437-21C5-475A-8191-505F21B570E0","name":"Existing","host":"example.com","port":22,"username":"root","group":"Personal","notes":"keep","authenticationType":"password","previewURL":""}
        """
        let server = try JSONDecoder().decode(ServerProfile.self, from: Data(json.utf8))
        XCTAssertEqual(server.notes, "keep")
        XCTAssertNil(server.isFavorite)
        XCTAssertNil(server.lastUsed)
    }
    @MainActor
    func testProfileUpdateFavoriteAndRecentPersist() {
        let suite = "ServerIDEProfileTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ServerStore(defaults: defaults)
        var profile = ServerProfile(name: "Original", host: "example.com", username: "root")
        store.add(profile)
        profile.name = "Edited"
        store.update(profile)
        store.toggleFavorite(profile.id)
        store.markUsed(profile.id)
        let loaded = ServerStore(defaults: defaults)
        XCTAssertEqual(loaded.servers.count, 1)
        XCTAssertEqual(loaded.servers[0].id, profile.id)
        XCTAssertEqual(loaded.servers[0].name, "Edited")
        XCTAssertEqual(loaded.servers[0].isFavorite, true)
        XCTAssertNotNil(loaded.servers[0].lastUsed)
    }
    @MainActor
    func testIndependentCommandTabs() {
        let workspace = TerminalWorkspace()
        let server = ServerProfile(name: "Test", host: "example.com", username: "root")
        workspace.open(server)
        workspace.open(server)
        XCTAssertEqual(workspace.sessions.count, 2)
        workspace.sessions[0].model.command = "first"
        XCTAssertEqual(workspace.sessions[1].model.command, "")
        workspace.sessions[0].model.isRunning = true
        let first = workspace.sessions[0].id
        workspace.close(first)
        XCTAssertEqual(workspace.sessions.count, 2)
        workspace.sessions[0].model.isRunning = false
        workspace.close(first)
        XCTAssertEqual(workspace.sessions.count, 1)
    }
    func testRemoteMetadataDecode() throws {
        let json = """
        {"ok":true,"path":"/root","files":[{"name":"file.py","path":"/root/file.py","isDirectory":false,"size":20,"modified":1780000000,"permissions":"-rw-------"}]}
        """
        let reply = try RemoteFileBridge.decode(json)
        XCTAssertEqual(reply.files?.first?.id, "/root/file.py")
        XCTAssertEqual(reply.files?.first?.size, 20)
        XCTAssertThrowsError(try RemoteFileBridge.decode("{\"ok\":false,\"error\":\"denied\"}"))
    }
    func testSubnet24() throws {
        let subnet = try IPv4Subnet("192.168.1.15/24")
        XCTAssertEqual(subnet.network, "192.168.1.0")
        XCTAssertEqual(subnet.mask, "255.255.255.0")
        XCTAssertEqual(subnet.broadcast, "192.168.1.255")
        XCTAssertEqual(subnet.firstHost, "192.168.1.1")
        XCTAssertEqual(subnet.lastHost, "192.168.1.254")
        XCTAssertEqual(subnet.usableHosts, 254)
    }
    func testSubnetBoundaries() throws {
        let zero = try IPv4Subnet("1.2.3.4/0")
        XCTAssertEqual(zero.addresses, 4_294_967_296)
        XCTAssertEqual(zero.mask, "0.0.0.0")
        XCTAssertEqual(zero.network, "0.0.0.0")
        let pair = try IPv4Subnet("10.0.0.1/31")
        XCTAssertEqual(pair.firstHost, "10.0.0.0")
        XCTAssertEqual(pair.lastHost, "10.0.0.1")
        XCTAssertEqual(pair.usableHosts, 2)
        let host = try IPv4Subnet("255.255.255.255/32")
        XCTAssertEqual(host.firstHost, "255.255.255.255")
        XCTAssertEqual(host.usableHosts, 1)
    }
    func testInvalidSubnets() {
        for input in ["", "1.2.3/24", "256.1.1.1/24", "1.2.3.4/33", "1.2.3.4/-1", "1..3.4/24", "1.2.3.4", "a.b.c.d/24"] {
            XCTAssertThrowsError(try IPv4Subnet(input), input)
        }
    }
    func testTextRoundTrips() throws {
        let sample = "مرحبا / hello + ? & 😀\n"
        XCTAssertEqual(try TextTransform.base64Decode.apply(TextTransform.base64Encode.apply(sample)), sample)
        XCTAssertEqual(try TextTransform.urlDecode.apply(TextTransform.urlEncode.apply(sample)), sample)
        XCTAssertThrowsError(try TextTransform.base64Decode.apply("%%%"))
        XCTAssertThrowsError(try TextTransform.urlDecode.apply("%ZZ"))
        XCTAssertThrowsError(try TextTransform.jsonPretty.apply("{bad}"))
        XCTAssertTrue(try TextTransform.jsonPretty.apply("{\"a\":1}").contains("\"a\""))
    }
    func testPasswordBoundsAndAlphabet() {
        XCTAssertEqual(PasswordGenerator.generate(length: 1, symbols: false).count, 12)
        XCTAssertEqual(PasswordGenerator.generate(length: 1000, symbols: false).count, 128)
        let alphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        for _ in 0..<100 {
            let password = PasswordGenerator.generate(length: 32, symbols: false)
            XCTAssertEqual(password.count, 32)
            XCTAssertTrue(password.allSatisfy { alphabet.contains($0) })
        }
    }
    func testShellQuote() {
        XCTAssertEqual(SSHConnectionManager.shellQuote("a'b"), "'a'\\''b'")
        XCTAssertEqual(SSHConnectionManager.shellQuote("$(touch x)"), "'$(touch x)'")
    }
    @MainActor
    func testSnippetPersistence() {
        let suite = "ServerIDETests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SnippetStore(defaults: defaults)
        let snippet = CommandSnippet(title: "Test", command: "pwd", category: "Tests")
        store.save(snippet)
        XCTAssertEqual(SnippetStore(defaults: defaults).items.last?.command, "pwd")
        store.favorite(snippet.id)
        XCTAssertEqual(SnippetStore(defaults: defaults).items.last?.favorite, true)
        var edited = snippet
        edited.command = "uname"
        store.save(edited)
        XCTAssertEqual(SnippetStore(defaults: defaults).items.filter { $0.id == snippet.id }.count, 1)
        XCTAssertEqual(SnippetStore(defaults: defaults).items.last?.command, "uname")
        store.delete(snippet.id)
        XCTAssertFalse(SnippetStore(defaults: defaults).items.contains { $0.id == snippet.id })
    }
}
