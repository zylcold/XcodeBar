import Foundation

struct SecurityScopedAccess {
    let url: URL

    static func start(for folder: ScanFolder?) -> SecurityScopedAccess? {
        guard let bookmarkData = folder?.securityScopedBookmarkData else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard !isStale, url.startAccessingSecurityScopedResource() else { return nil }
            return SecurityScopedAccess(url: url)
        } catch {
            return nil
        }
    }

    func stop() {
        url.stopAccessingSecurityScopedResource()
    }
}
