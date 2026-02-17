import SwiftUI

/// Editor for league context (inside jokes, personalities, culture notes) used by roast generation
struct LeagueContextView: View {
    let league: LeagueConnection
    @Bindable var viewModel: LeagueContextViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddJoke = false
    @State private var showingAddPersonality = false
    @State private var editingJoke: LeagueContext.InsideJoke?
    @State private var editingPersonality: LeagueContext.PlayerPersonality?
    
    private var isSaving: Bool { viewModel.saveState == .saving }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Inside Jokes") {
                    ForEach(viewModel.insideJokes) { joke in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(joke.term).font(.headline)
                            Text(joke.explanation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingJoke = joke }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { viewModel.removeInsideJoke(id: viewModel.insideJokes[$0].id) }
                    }
                    Button { showingAddJoke = true } label: {
                        Label("Add Inside Joke", systemImage: "plus.circle")
                    }
                }
                
                Section("Player Personalities") {
                    ForEach(viewModel.personalities) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.playerName).font(.headline)
                            Text(p.description).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingPersonality = p }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { viewModel.removePersonality(id: viewModel.personalities[$0].id) }
                    }
                    Button { showingAddPersonality = true } label: {
                        Label("Add Personality", systemImage: "plus.circle")
                    }
                }
                
                Section("Sacko Punishment") {
                    TextEditor(text: $viewModel.sackoPunishment)
                        .frame(minHeight: 60, maxHeight: 120)
                }
                
                Section("League Culture Notes") {
                    TextEditor(text: $viewModel.cultureNotes)
                        .frame(minHeight: 100, maxHeight: 200)
                }
                
                Section {
                    Button(action: { viewModel.saveContext() }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().controlSize(.small)
                                Text("Saving...")
                            } else {
                                Text("Save Context").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("League Context")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddJoke) { AddInsideJokeView(viewModel: viewModel) }
            .sheet(item: $editingJoke) { joke in EditInsideJokeView(viewModel: viewModel, joke: joke) }
            .sheet(isPresented: $showingAddPersonality) { AddPersonalityView(viewModel: viewModel) }
            .sheet(item: $editingPersonality) { p in EditPersonalityView(viewModel: viewModel, personality: p) }
        }
    }
}

// MARK: - Add/Edit Inside Joke

struct AddInsideJokeView: View {
    var viewModel: LeagueContextViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var explanation = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Term", text: $term)
                    TextEditor(text: $explanation)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if explanation.isEmpty {
                                Text("Explanation").foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 4)
                            }
                        }
                }
            }
            .navigationTitle("Add Inside Joke")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addInsideJoke(term: term, explanation: explanation)
                        dismiss()
                    }
                    .disabled(term.isEmpty || explanation.isEmpty)
                }
            }
        }
    }
}

struct EditInsideJokeView: View {
    var viewModel: LeagueContextViewModel
    let joke: LeagueContext.InsideJoke
    @Environment(\.dismiss) private var dismiss
    @State private var term: String
    @State private var explanation: String
    
    init(viewModel: LeagueContextViewModel, joke: LeagueContext.InsideJoke) {
        self.viewModel = viewModel
        self.joke = joke
        _term = State(initialValue: joke.term)
        _explanation = State(initialValue: joke.explanation)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Term", text: $term)
                    TextEditor(text: $explanation).frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Inside Joke")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.editInsideJoke(id: joke.id, term: term, explanation: explanation)
                        dismiss()
                    }
                    .disabled(term.isEmpty || explanation.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add/Edit Personality

struct AddPersonalityView: View {
    var viewModel: LeagueContextViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var playerName = ""
    @State private var playerDescription = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Player Name", text: $playerName)
                    TextEditor(text: $playerDescription)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if playerDescription.isEmpty {
                                Text("Description").foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 4)
                            }
                        }
                }
            }
            .navigationTitle("Add Personality")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addPersonality(playerName: playerName, description: playerDescription)
                        dismiss()
                    }
                    .disabled(playerName.isEmpty || playerDescription.isEmpty)
                }
            }
        }
    }
}

struct EditPersonalityView: View {
    var viewModel: LeagueContextViewModel
    let personality: LeagueContext.PlayerPersonality
    @Environment(\.dismiss) private var dismiss
    @State private var playerName: String
    @State private var playerDescription: String
    
    init(viewModel: LeagueContextViewModel, personality: LeagueContext.PlayerPersonality) {
        self.viewModel = viewModel
        self.personality = personality
        _playerName = State(initialValue: personality.playerName)
        _playerDescription = State(initialValue: personality.description)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Player Name", text: $playerName)
                    TextEditor(text: $playerDescription).frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit Personality")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.editPersonality(id: personality.id, playerName: playerName, description: playerDescription)
                        dismiss()
                    }
                    .disabled(playerName.isEmpty || playerDescription.isEmpty)
                }
            }
        }
    }
}
