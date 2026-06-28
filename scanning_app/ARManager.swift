//
//  scanning_appApp.swift
//  scanning_app
//
//  Created by arronax on 3/16/26.
//
import ARKit
import RealityKit
import SwiftUI

class ARManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isRecording = false
    @Published var statusMessage = "ПОИСК ПОВЕРХНОСТИ..."
    @Published var trackingQuality: ARCamera.TrackingState = .notAvailable
    @Published var scans: [URL] = []
    
    // Управление проектами
    @Published var currentProjectName: String = "Default"
    @Published var availableProjects: [String] = []

    var arView: ARView = ARView(frame: .zero)
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]

    override init() {
        super.init()
        createRootDirectory()
        loadProjects()
        loadScans()
        startSession()
    }

    func startSession() {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func toggleRecording() {
        if isRecording {
            isRecording = false
            arView.debugOptions = []
            exportMeshManually()
        } else {
            if case .normal = trackingQuality {
                meshAnchors.removeAll()
                isRecording = true
                arView.debugOptions = [.showSceneUnderstanding]
                statusMessage = "ЗАПИСЬ..."
            }
        }
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { updateAnchors(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { updateAnchors(anchors) }
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let mesh = anchor as? ARMeshAnchor { meshAnchors.removeValue(forKey: mesh.identifier) }
        }
    }

    private func updateAnchors(_ anchors: [ARAnchor]) {
        guard isRecording else { return }
        for anchor in anchors {
            if let mesh = anchor as? ARMeshAnchor { meshAnchors[mesh.identifier] = mesh }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            self.trackingQuality = camera.trackingState
            if !self.isRecording {
                self.statusMessage = (camera.trackingState == .normal) ? "ГОТОВ" : "КАЛИБРОВКА..."
            }
        }
    }

    // MARK: - Экспорт (Manual OBJ с Версиями)
    private func getNextVersion(for project: String, date: String) -> String {
        let path = getRootDirectory().appendingPathComponent(project)
        let files = (try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)) ?? []
        let pattern = "scan_\(date)_v"
        
        let versions = files.map { $0.lastPathComponent }
            .filter { $0.contains(pattern) }
            .compactMap { name -> Int? in
                let parts = name.components(separatedBy: "_v")
                if parts.count > 1 { return Int(parts[1].replacingOccurrences(of: ".obj", with: "")) }
                return nil
            }
        
        let nextNum = (versions.max() ?? 0) + 1
        return "v\(nextNum)"
    }

    private func exportMeshManually() {
        statusMessage = "СОХРАНЕНИЕ..."
        let currentAnchors = self.meshAnchors.values.map { $0 }
        let projectName = self.currentProjectName

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !currentAnchors.isEmpty else { return }

            let formatter = DateFormatter(); formatter.dateFormat = "dd_MM_yy"
            let dateStr = formatter.string(from: Date())
            let version = self.getNextVersion(for: projectName, date: dateStr)
            let fileName = "scan_\(dateStr)_\(version).obj"

            var objContent = "# Project: \(projectName)\n"
            var vOffset: UInt32 = 1
            var vData = ""
            var fData = ""

            for anchor in currentAnchors {
                let geom = anchor.geometry
                let xform = anchor.transform
                let vPtr = geom.vertices.buffer.contents()
                
                for i in 0..<geom.vertices.count {
                    let rawV = vPtr.advanced(by: i * geom.vertices.stride).bindMemory(to: SIMD3<Float>.self, capacity: 1).pointee
                    let worldV = xform * SIMD4<Float>(rawV, 1)
                    vData += "v \(worldV.x) \(worldV.y) \(worldV.z)\n"
                }

                let fPtr = geom.faces.buffer.contents().bindMemory(to: UInt32.self, capacity: geom.faces.count * 3)
                for i in 0..<geom.faces.count {
                    let i1 = fPtr[i * 3] + vOffset
                    let i2 = fPtr[i * 3 + 1] + vOffset
                    let i3 = fPtr[i * 3 + 2] + vOffset
                    fData += "f \(i1) \(i2) \(i3)\n"
                }
                vOffset += UInt32(geom.vertices.count)
            }

            let url = self.getRootDirectory().appendingPathComponent(projectName).appendingPathComponent(fileName)
            try? (objContent + vData + fData).write(to: url, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                self.statusMessage = "ГОТОВО: \(fileName)"
                self.loadScans()
            }
        }
    }

    // MARK: - Файловая система
    func loadProjects() {
        let root = getRootDirectory()
        let content = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let projects = content?.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent }.sorted() ?? []
        
        DispatchQueue.main.async {
            self.availableProjects = projects.isEmpty ? ["Default"] : projects
            if !self.availableProjects.contains("Default") { self.createProject(name: "Default") }
        }
    }

    func createProject(name: String) {
        let path = getRootDirectory().appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        loadProjects()
    }

    func loadScans() {
        let path = getRootDirectory().appendingPathComponent(currentProjectName)
        let files = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
        DispatchQueue.main.async {
            self.scans = files?.filter { $0.pathExtension == "obj" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) ?? []
        }
    }

    func deleteScan(at offsets: IndexSet) {
        let path = getRootDirectory().appendingPathComponent(currentProjectName)
        offsets.forEach { index in
            try? FileManager.default.removeItem(at: scans[index])
        }
        loadScans()
    }

    private func getRootDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Scans")
    }
    
    private func createRootDirectory() {
        try? FileManager.default.createDirectory(at: getRootDirectory(), withIntermediateDirectories: true)
    }
}
