//
//  ModelSceneView.swift
//  scanning_app
//
//  Created by arronax on 3/17/26.
//
import SwiftUI
import RealityKit
import Combine

struct ModelSceneView: UIViewRepresentable {
    let modelURL: URL

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(.black)

        do {
            let modelEntity = try Entity.loadModel(contentsOf: modelURL)
                let anchor = AnchorEntity(world: .zero)
                
                // 1. АВТО-МАСШТАБИРОВАНИЕ
                // Вычисляем визуальные границы модели (Bounding Box)
                let bounds = modelEntity.visualBounds(relativeTo: nil)
                let size = bounds.extents
                let maxDimension = max(size.x, max(size.y, size.z))
                
                // Рассчитываем коэффициент, чтобы модель была примерно 1 метр в диаметре во вьюпорте
                let targetSize: Float = 1.0
                let scaleFactor = targetSize / maxDimension
                modelEntity.scale = [scaleFactor, scaleFactor, scaleFactor]
                
                // 2. ЦЕНТРОВКА
                // Сдвигаем модель так, чтобы её геометрический центр был в точке (0,0,0)
                modelEntity.position = -bounds.center * scaleFactor
                
                anchor.addChild(modelEntity)
                arView.scene.addAnchor(anchor)

                // 3. СВЕТ И КАМЕРА (пододвинем поближе)
                let light = DirectionalLight()
                light.light.intensity = 5000
                let lightAnchor = AnchorEntity(world: [0, 2, 2])
                arView.scene.addAnchor(lightAnchor)

                let cameraEntity = PerspectiveCamera()
                // Ставим камеру на расстоянии 1.2 метра — теперь модель будет на весь экран
                let cameraAnchor = AnchorEntity(world: [0, 0, 1.2])
                cameraAnchor.addChild(cameraEntity)
                arView.scene.addAnchor(cameraAnchor)

                // 4. ЖЕСТЫ И ВРАЩЕНИЕ
                modelEntity.generateCollisionShapes(recursive: true)
                arView.installGestures([.all], for: modelEntity)
                
                context.coordinator.setupRotation(modelEntity)
        } catch {
            print("Ошибка загрузки модели: \(error)")
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // Координатор нужен для обработки кадров (анимации)
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var subscriptions = Set<AnyCancellable>()

        func setupRotation(_ entity: Entity) {
            entity.scene?.subscribe(to: SceneEvents.Update.self) { event in
                // Добавляем 'f' к типу и Float к значениям
                let rotation = simd_quaternion(Float(0.01), simd_make_float3(0, 1, 0))
                entity.orientation *= rotation
            }.store(in: &subscriptions)
        }
    }
}
