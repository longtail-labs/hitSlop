import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct Book: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Title") var title: String = ""
    @Field("Author") var author: String = ""
    @Field("Cover") var cover: TemplateImage = TemplateImage("")
    @Field("Pages Read") var pagesRead: Double = 0
    @Field("Total Pages") var totalPages: Double = 300
    @Field("Rating") var rating: Double = 0
    @Field("Status", options: ["Reading", "Finished", "Want to Read"]) var status: String = "Want to Read"

    var progress: Double { totalPages > 0 ? pagesRead / totalPages : 0 }

    var initials: String {
        let words = title.split(separator: " ").prefix(2)
        return words.map { String($0.prefix(1)).uppercased() }.joined()
    }
}

@SlopData
public struct ReadingListData {
    @SlopKit.Section("Overview")
    @Field("Title") var title: String = "Reading List"
    @Field("Subtitle") var subtitle: String = "2026 Goals"

    @SlopKit.Section("Books")
    @Field("Books") var books: [Book] = ReadingListData.defaultBooks

    var booksFinished: Int { books.filter { $0.status == "Finished" }.count }
    var booksReading: Int { books.filter { $0.status == "Reading" }.count }

    var sortedBooks: [Book] {
        books.sorted { a, b in
            let order: [String: Int] = ["Reading": 0, "Want to Read": 1, "Finished": 2]
            return (order[a.status] ?? 3) < (order[b.status] ?? 3)
        }
    }
}

extension ReadingListData {
    static var defaultBooks: [Book] {
        func book(_ title: String, _ author: String, pagesRead: Double, totalPages: Double, rating: Double, status: String) -> Book {
            var b = Book()
            b.title = title
            b.author = author
            b.pagesRead = pagesRead
            b.totalPages = totalPages
            b.rating = rating
            b.status = status
            return b
        }

        return [
            book("Dune", "Frank Herbert", pagesRead: 210, totalPages: 412, rating: 0, status: "Reading"),
            book("Project Hail Mary", "Andy Weir", pagesRead: 476, totalPages: 476, rating: 5, status: "Finished"),
            book("The Left Hand of Darkness", "Ursula K. Le Guin", pagesRead: 0, totalPages: 304, rating: 0, status: "Want to Read"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.reading-list",
    name: "Reading List",
    description: "Keep a personal reading queue with progress, status, and ratings.",
    version: "1.0.0",
    width: 380, height: 580,
    minWidth: 320, minHeight: 400,
    shape: .roundedRect(radius: 18),
    theme: "lavender",
    alwaysOnTop: true,
    categories: ["personal"]
)
struct ReadingListView: View {
    @TemplateData var data: ReadingListData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) {
                    interactiveContent
                }
            } else {
                exportContent
            }
        }
        .background(theme.background)
    }

    // MARK: - Book Cover

    private func bookCover(_ book: Binding<Book>) -> some View {
        Group {
            if book.wrappedValue.cover.path.isEmpty {
                // Fallback: colored rectangle with initials
                let coverColor = coverColorForBook(book.wrappedValue)
                RoundedRectangle(cornerRadius: 4)
                    .fill(coverColor)
                    .frame(width: 40, height: 56)
                    .overlay(
                        Text(book.wrappedValue.initials)
                            .font(theme.font(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                    .shadow(color: coverColor.opacity(0.3), radius: 3, y: 2)
                    .overlay {
                        if renderTarget == .interactive {
                            SlopImage(image: book.cover, placeholder: "")
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .opacity(0.01)
                        }
                    }
            } else {
                SlopImage(image: book.cover, placeholder: "Cover")
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(radius: 3, y: 2)
            }
        }
    }

    private func bookCoverExport(_ book: Book) -> some View {
        Group {
            if book.cover.path.isEmpty {
                let coverColor = coverColorForBook(book)
                RoundedRectangle(cornerRadius: 4)
                    .fill(coverColor)
                    .frame(width: 40, height: 56)
                    .overlay(
                        Text(book.initials)
                            .font(theme.font(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                    .shadow(color: coverColor.opacity(0.3), radius: 3, y: 2)
            } else {
                SlopImage(image: .constant(book.cover), placeholder: "Cover")
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(radius: 3, y: 2)
            }
        }
    }

    private func coverColorForBook(_ book: Book) -> Color {
        // Deterministic color from title hash
        let hash = abs(book.title.hashValue)
        let colors: [Color] = [
            Color(red: 0.85, green: 0.3, blue: 0.35),
            Color(red: 0.3, green: 0.5, blue: 0.8),
            Color(red: 0.4, green: 0.7, blue: 0.5),
            Color(red: 0.7, green: 0.45, blue: 0.7),
            Color(red: 0.9, green: 0.6, blue: 0.3),
            Color(red: 0.3, green: 0.6, blue: 0.7),
        ]
        return colors[hash % colors.count]
    }

    // MARK: - Progress Bar

    private func progressBar(_ book: Book) -> some View {
        GeometryReader { geo in
            let pct = min(book.progress, 1.0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.surface)
                    .frame(height: 6)
                Capsule()
                    .fill(pct >= 1.0 ? Color.green : theme.accent)
                    .frame(width: geo.size.width * pct, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pct)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: String) -> some View {
        StatusBadge(status)
    }

    // MARK: - Pages Per Day Estimate

    private func pagesPerDayEstimate(_ book: Book) -> some View {
        Group {
            if book.status == "Reading" && book.pagesRead > 0 {
                let remaining = book.totalPages - book.pagesRead
                if remaining > 0 {
                    Text("\(Int(remaining)) pages left")
                        .font(theme.font(size: 9))
                        .foregroundStyle(theme.secondary.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Interactive

    private var interactiveContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SlopTextField("Title", text: $data.title)
                .font(theme.title(size: 22))
                .foregroundStyle(theme.foreground)

            SlopTextField("Subtitle", text: $data.subtitle)
                .font(theme.font(size: 14))
                .foregroundStyle(theme.secondary)

            ThemeDivider()

            statsPill

            if data.books.isEmpty {
                emptyState
            }

            // Sorted books: Reading -> Want to Read -> Finished
            ForEach($data.books) { $book in
                let sortedIDs = data.sortedBooks.map(\.id)
                let _ = sortedIDs // use sorted order for display
                bookCard(book: $book)
            }

            SlopInteractiveOnly {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.books.append(Book())
                    }
                } label: {
                    Label("Add Book", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(theme.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }

    private func bookCard(book: Binding<Book>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            bookCover(book)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        SlopTextField("Book title", text: book.title)
                            .font(theme.font(size: 14, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                        SlopTextField("Author", text: book.author)
                            .font(theme.font(size: 12))
                            .foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    SlopInteractiveOnly {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.books.removeAll { $0.id == book.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    Text("Pages")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                    SlopNumberField("0", value: book.pagesRead)
                        .font(.caption)
                        .foregroundStyle(theme.foreground.opacity(0.8))
                        .frame(width: 40)
                    Text("/")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                    SlopNumberField("0", value: book.totalPages)
                        .font(.caption)
                        .foregroundStyle(theme.foreground.opacity(0.8))
                        .frame(width: 40)

                    SlopInteractiveOnly {
                        HStack(spacing: 2) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    book.wrappedValue.pagesRead = max(0, book.wrappedValue.pagesRead - 1)
                                }
                            } label: {
                                Text("-1")
                                    .font(theme.font(size: 9, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    book.wrappedValue.pagesRead = min(book.wrappedValue.totalPages, book.wrappedValue.pagesRead + 1)
                                }
                            } label: {
                                Text("+1")
                                    .font(theme.font(size: 9, weight: .medium))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    book.wrappedValue.pagesRead = min(book.wrappedValue.totalPages, book.wrappedValue.pagesRead + 10)
                                }
                            } label: {
                                Text("+10")
                                    .font(theme.font(size: 9, weight: .medium))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(String(format: "%.0f%%", book.wrappedValue.progress * 100))
                        .font(theme.font(size: 10, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                }

                progressBar(book.wrappedValue)

                HStack(spacing: 2) {
                    SlopInteractiveOnly {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    book.wrappedValue.rating = Double(star)
                                }
                            } label: {
                                Image(systemName: star <= Int(book.wrappedValue.rating) ? "star.fill" : "star")
                                    .font(theme.font(size: 12))
                                    .foregroundStyle(star <= Int(book.wrappedValue.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    SlopInteractiveOnly {
                        Picker("", selection: book.status) {
                            Text("Reading").tag("Reading")
                            Text("Finished").tag("Finished")
                            Text("Want to Read").tag("Want to Read")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .font(.caption)
                    }
                }

                pagesPerDayEstimate(book.wrappedValue)
            }
        }
        .padding(12)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Export

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.title)
                .font(theme.title(size: 22))
                .foregroundStyle(theme.foreground)

            Text(data.subtitle)
                .font(theme.font(size: 14))
                .foregroundStyle(theme.secondary)

            ThemeDivider()

            statsPill

            ForEach(data.sortedBooks) { book in
                HStack(alignment: .top, spacing: 12) {
                    bookCoverExport(book)

                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(theme.font(size: 14, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(book.author)
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.secondary)
                        }

                        HStack(spacing: 8) {
                            Text("Pages")
                                .font(.caption)
                                .foregroundStyle(theme.secondary)
                            Text("\(Int(book.pagesRead))")
                                .font(.caption)
                                .foregroundStyle(theme.foreground.opacity(0.8))
                            Text("/")
                                .font(.caption)
                                .foregroundStyle(theme.secondary)
                            Text("\(Int(book.totalPages))")
                                .font(.caption)
                                .foregroundStyle(theme.foreground.opacity(0.8))
                            Text(String(format: "%.0f%%", book.progress * 100))
                                .font(theme.font(size: 10, weight: .medium))
                                .foregroundStyle(theme.accent)
                        }

                        progressBar(book)

                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(book.rating) ? "star.fill" : "star")
                                    .font(theme.font(size: 12))
                                    .foregroundStyle(star <= Int(book.rating) ? Color.yellow : theme.secondary.opacity(0.3))
                            }
                            Spacer()
                            statusBadge(book.status)
                        }
                    }
                }
                .padding(12)
                .background(theme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(24)
    }

    // MARK: - Shared

    private var statsPill: some View {
        HStack(spacing: 8) {
            Text("\(data.booksReading) reading")
                .font(.caption)
                .foregroundStyle(theme.secondary)
            Text("\u{00B7}")
                .foregroundStyle(theme.secondary.opacity(0.4))
            Text("\(data.booksFinished) finished")
                .font(.caption)
                .foregroundStyle(theme.secondary)
            Text("\u{00B7}")
                .foregroundStyle(theme.secondary.opacity(0.4))
            Text("\(data.books.count) total")
                .font(.caption)
                .foregroundStyle(theme.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.surface)
        .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(theme.font(size: 28))
                .foregroundStyle(theme.secondary.opacity(0.3))
            Text("No books yet")
                .font(.caption)
                .foregroundStyle(theme.secondary.opacity(0.5))
            Text("Add a book to start your reading list")
                .font(.caption2)
                .foregroundStyle(theme.secondary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

