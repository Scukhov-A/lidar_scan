//
//  scanning_appApp.swift
//  scanning_app
//
//  Created by arronax on 3/16/26.
//
import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @StateObject private var arManager = ARManager()
    @State private var showGallery = false
    @State private var showNewProjectAlert = false
    @State private var newProjectName = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ВЕРХНЯЯ ПАНЕЛЬ: ПРОЕКТЫ
                HStack {
                    Menu {
                        Section("Выбрать папку") {
                            ForEach(arManager.availableProjects, id: \.self) { project in
                                Button {
                                    arManager.currentProjectName = project
                                    arManager.loadScans()
                                } label: {
                                    HStack {
                                        Text(project)
                                        if project == arManager.currentProjectName { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                        Button(action: { showNewProjectAlert = true }) {
                            Label("Новая папка", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                            Text(arManager.currentProjectName.uppercased())
                                .font(.system(.subheadline, design: .monospaced).bold())
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
                    }
                    Spacer()
                    
                    // Индикатор качества
                    Circle()
                        .fill(arManager.trackingQuality == .normal ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 20).padding(.top, 10)

                // ВИДЖЕТ КАМЕРЫ
                ARViewContainer(arView: arManager.arView)
                    .cornerRadius(24)
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                
                Text(arManager.statusMessage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(arManager.isRecording ? .red : .white)
                    .padding(.vertical, 10)
                
                // ПАНЕЛЬ КНОПОК
                HStack(spacing: 60) {
                    Button(action: { showGallery = true }) {
                        VStack {
                            Image(systemName: "square.grid.2x2.fill").font(.title2)
                            Text("АРХИВ").font(.caption2).bold()
                        }
                    }.foregroundColor(.white)
                    
                    Button(action: { arManager.toggleRecording() }) {
                        ZStack {
                            Circle().stroke(Color.white, lineWidth: 3).frame(width: 75, height: 75)
                            if arManager.isRecording {
                                RoundedRectangle(cornerRadius: 8).fill(Color.red).frame(width: 30, height: 30)
                            } else {
                                Circle().fill(Color.white).frame(width: 60, height: 60)
                            }
                        }
                    }
                    
                    Spacer().frame(width: 40)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showGallery) {
            GalleryView(arManager: arManager)
        }
        .alert("Новый проект", isPresented: $showNewProjectAlert) {
            TextField("Название папки", text: $newProjectName)
            Button("Отмена", role: .cancel) { newProjectName = "" }
            Button("Создать") {
                if !newProjectName.isEmpty {
                    arManager.createProject(name: newProjectName)
                    arManager.currentProjectName = newProjectName
                    arManager.loadScans()
                    newProjectName = ""
                }
            }
        }
    }
}

// MARK: - ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    let arView: ARView
    func makeUIView(context: Context) -> ARView { return arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - GalleryView (Список файлов в текущей папке)
struct GalleryView: View {
    @ObservedObject var arManager: ARManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if arManager.scans.isEmpty {
                    VStack {
                        Image(systemName: "folder.badge.questionmark").font(.largeTitle).padding()
                        Text("В папке '\(arManager.currentProjectName)' пока нет сканов").foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(arManager.scans, id: \.self) { scan in
                            NavigationLink(destination: DetailView(modelURL: scan)) {
                                ScanRow(scanURL: scan)
                            }
                        }
                        .onDelete(perform: arManager.deleteScan)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle(arManager.currentProjectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ScanRow
struct ScanRow: View {
    let scanURL: URL
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "arkit").foregroundColor(.blue).frame(width: 30)
            VStack(alignment: .leading) {
                Text(scanURL.lastPathComponent).font(.system(.subheadline, design: .monospaced)).lineLimit(1)
                Text("3D LiDAR Mesh").font(.caption2).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - DetailView (Просмотр 3D)
struct DetailView: View {
    let modelURL: URL
    var body: some View {
        VStack {
            ModelSceneView(modelURL: modelURL)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
        }
        .navigationTitle("Просмотр")
        .toolbar {
            Button(action: { shareFile(url: modelURL) }) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
    
    func shareFile(url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.present(av, animated: true)
        }
    }
}
