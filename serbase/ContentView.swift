//
//  ContentView.swift
//  serbase
//  Created by 구리뽕 on 6/8/25.

enum ImportSource { case iCloud, iDrive, local }

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFilter = "All Items"
    @State private var selectedSidebarItem = "Library"
    @State private var searchText = ""

    let filterOptions = ["All Items", "Photos", "Videos", "Live Photos"]

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedSidebarItem)
        } content: {
            // 중간 패널은 비워두거나 필요에 따라 추가
            EmptyView()
        } detail: {
            MainContentView(selectedFilter: $selectedFilter, searchText: $searchText, filterOptions: filterOptions)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct SidebarView: View {
    @Binding var selectedItem: String

    var body: some View {
        List(selection: $selectedItem) {
            Section {
                SidebarRow(icon: "folder.fill", title: "Library", selectedItem: $selectedItem)
                SidebarRow(icon: "heart.fill", title: "Favorites", selectedItem: $selectedItem)
                SidebarRow(icon: "clock.fill", title: "Recently Saved", selectedItem: $selectedItem)
                SidebarRow(icon: "map.fill", title: "Map", selectedItem: $selectedItem)
            }

            Section {
                SidebarRow(icon: "calendar", title: "Days", selectedItem: $selectedItem)
                SidebarRow(icon: "person.2.fill", title: "People & Pets", selectedItem: $selectedItem)
                SidebarRow(icon: "star.fill", title: "Memories", selectedItem: $selectedItem)
                SidebarRow(icon: "airplane", title: "Trips", selectedItem: $selectedItem)
                SidebarRow(icon: "sparkles", title: "Featured Photos", selectedItem: $selectedItem)
                SidebarRow(icon: "rectangle.stack.fill", title: "Albums", selectedItem: $selectedItem)
                SidebarRow(icon: "play.rectangle.fill", title: "Media Types", selectedItem: $selectedItem)
                SidebarRow(icon: "folder.badge.gearshape", title: "Utilities", selectedItem: $selectedItem)
                SidebarRow(icon: "hammer.fill", title: "Projects", selectedItem: $selectedItem)
            }

            Section("Sharing") {
                SidebarRow(icon: "person.2.crop.square.stack.fill", title: "Shared Albums", selectedItem: $selectedItem)
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

struct SidebarRow: View {
    let icon: String
    let title: String
    @Binding var selectedItem: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(title)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = title
        }
    }
}

struct MainContentView: View {
    @Binding var selectedFilter: String
    @Binding var searchText: String
    let filterOptions: [String]
    @State private var mediaItems: [MediaItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // 상단 툴바
            TopToolbarView(selectedFilter: $selectedFilter, searchText: $searchText, filterOptions: filterOptions) { source in
                importMedia(from: source)
            }

            // 날짜 헤더
            DateHeaderView()

            // 사진 그리드
            PhotoGridView(items: $mediaItems)
        }
    }

    private func importMedia(from source: ImportSource) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = true
        switch source {
        case .iCloud:
            panel.directoryURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
        case .iDrive:
            panel.directoryURL = URL(fileURLWithPath: "/Volumes/IDrive")
        case .local:
            break
        }
        if panel.runModal() == .OK {
            mediaItems.append(contentsOf: panel.urls.map { MediaItem(url: $0) })
        }
    }
}

struct TopToolbarView: View {
    @Binding var selectedFilter: String
    @Binding var searchText: String
    let filterOptions: [String]
    var importAction: (ImportSource) -> Void

    var body: some View {
        HStack {
            // 네비게이션 버튼들
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                }
                Button(action: {}) {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // 뷰 컨트롤
            HStack {
                Text("Years")
                Text("Months")
                Text("All Photos")
                    .fontWeight(.medium)
            }
            .font(.system(size: 13))

            Spacer()

            // 검색 및 필터
            HStack {
                // 검색바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 150)

                // 필터 드롭다운
                Menu {
                    ForEach(filterOptions, id: \.self) { option in
                        Button(option) {
                            selectedFilter = option
                        }
                    }
                } label: {
                    HStack {
                        Text("Filter By: \(selectedFilter)")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(BorderlessButtonMenuStyle())

                Menu {
                    Button("From iCloud") { importAction(.iCloud) }
                    Button("From IDrive") { importAction(.iDrive) }
                    Button("From Folder") { importAction(.local) }
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor))
    }
}

struct DateHeaderView: View {
    var body: some View {
        HStack {
            Text("Mar 15, 2024")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct PhotoGridView: View {
    @Binding var items: [MediaItem]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(items) { item in
                    PhotoThumbnailView(item: item)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct PhotoThumbnailView: View {
    let item: MediaItem
    @State private var isHovered = false

    var body: some View {
        ZStack {
            if let nsImage = NSImage(contentsOf: item.url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
            .overlay(
                // 호버 효과
                Rectangle()
                    .fill(Color.white.opacity(isHovered ? 0.2 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            )
            .cornerRadius(8)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                // 사진 선택 로직
                print("Selected photo: \(item.id)")
            }
    }
}

// 데이터 모델
struct MediaItem: Identifiable {
    let id = UUID()
    let url: URL
}

// 프리뷰
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}

