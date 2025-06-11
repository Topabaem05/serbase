//
//  PhotoInfoView.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI
import MapKit

struct PhotoInfoView: View {
    let photo: PhotoItem
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            InfoRow(label: "File Path", value: photo.sourceURL?.path ?? "N/A")
            
            if let creationDate = photo.creationDate {
                InfoRow(label: "Created", value: dateFormatter.string(from: creationDate))
            }
            
            if let modificationDate = photo.modificationDate {
                InfoRow(label: "Modified", value: dateFormatter.string(from: modificationDate))
            }
            
            if photo.location != nil {
                InfoMapView(coordinate: photo.coordinate)
                    .frame(height: 150)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

struct InfoMapView: View {
    let coordinate: CLLocationCoordinate2D
    
    @State private var region: MKCoordinateRegion
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [Pin(coordinate: coordinate)]) { pin in
            MapMarker(coordinate: pin.coordinate)
        }
    }
    
    private struct Pin: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
} 