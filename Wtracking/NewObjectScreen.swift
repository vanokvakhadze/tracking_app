//
//  NewObjectScreen.swift
//  Wtracking
//
//  Created by vano Kvakhadze on 24.02.26.
//

import SwiftUI
import PhotosUI

struct NewObjectScreen: View {
    @Binding var typedTitle: String
    @Binding var typedAddress: String
    @Binding var selectedImageData: Data?

    var onCancel: () -> Void
    var onSave: () -> Void
    @FocusState.Binding  var isTitleFocused: Bool
    @FocusState var dummyFocus
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack{
            VStack(spacing: 16) {
                Text("ლოკაციის დეტალები")
                    .font(.headline)
                
             
                TextField("ობიექტის სახელი", text: $typedTitle)
                    .focused($isTitleFocused)
                    .frame(height: 35)
                    .textFieldStyle(.roundedBorder)

                
                TextField("მისამართი", text: $typedAddress)
                    .frame(height: 35)
                    .textFieldStyle(.roundedBorder)


                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(selectedImageData == nil ? "ფოტოს არჩევა" : "ფოტო არჩეულია ✅")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15)))
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run { selectedImageData = data }
                        }
                    }
                }
          
                    
                    if let data = selectedImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 200, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                     sysImage(image: "trash", width: 15, height: 15)
                                         .padding(8)
                                         .foregroundStyle(.red)
                                         .contentShape(Rectangle())
                                         .onTapGesture {
                                             selectedImageData = nil
                                         }
                                         .offset(x: 12, y: -12)
                                 }
                        
                    }
                    
                    
                
                
                HStack {
                    Button("გაუქმება", action: onCancel)
                    
                    Spacer()
                    
                    Button("შენახვა", action: onSave)
                        .disabled(typedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await Task.yield()
            isTitleFocused = true
        }
        
        .padding()
        .presentationDetents([.fraction(0.7) , .fraction(0.5)])
        .presentationCornerRadius(25)
    }
}
