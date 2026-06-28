//
//  SplashView.swift
//  scanning_app
//
//  Created by arronax on 3/16/26.
//
import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
                .transition(.opacity)
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 25) {

                    Image("oww")
                        .resizable()    // Позволяет менять размер
                        .scaledToFit()  // Сохраняет пропорции
                        .frame(width: 150, height: 150)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    VStack(spacing: 10) {
                        Text("LIDAR SCANNER")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Инициализация AR...")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.top, 20)
                }
            }
            .onAppear {
                // Анимация появления
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    self.scale = 1.0
                    self.opacity = 1.0
                }
                
                // Переход к камере через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
