//
//  FullScreenPhotoView.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI

struct FullScreenPhotoView: View {
    let photo: PhotoItem
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
                .onTapGesture {
                    // 배경을 탭하면 닫기
                    isPresented = false
                }
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
            .buttonStyle(.plain)
        }
    }
} 