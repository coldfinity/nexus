import Foundation
import Darwin

/// Resolves a process's current working directory from its PID using libproc.
///
/// A custom terminal can't rely on the shell emitting OSC 7 cwd updates (macOS
/// only wires that up for Terminal.app), so we read the shell process's live cwd
/// directly. This tracks `cd` as it happens.
enum WorkingDirectory {
    static func of(pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard result > 0 else { return nil }

        return withUnsafeBytes(of: &info.pvi_cdir.vip_path) { rawBuffer in
            let base = rawBuffer.baseAddress!.assumingMemoryBound(to: CChar.self)
            let path = String(cString: base)
            return path.isEmpty ? nil : path
        }
    }
}
