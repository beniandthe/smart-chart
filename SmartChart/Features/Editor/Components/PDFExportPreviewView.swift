import PDFKit
import SwiftUI
import UIKit

struct ExportedPDF: Identifiable, Hashable {
    let url: URL
    let chartTitle: String

    var id: URL { url }

    var navigationTitle: String {
        let trimmedTitle = chartTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : trimmedTitle
    }
}

struct PDFExportPreviewView: View {
    let exportedPDF: ExportedPDF
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: exportedPDF.url)
                .background(Color(uiColor: .systemBackground))
                .navigationTitle(exportedPDF.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: [exportedPDF.url])
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        uiViewController.completionWithItemsHandler = nil
    }
}
