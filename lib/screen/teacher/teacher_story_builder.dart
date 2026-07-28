import 'package:flutter/material.dart';
import 'package:readright/services/story_service.dart';
import 'package:readright/widgets/teacher_base_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryStudent {
  final String id;
  final String name;

  const StoryStudent({
    required this.id,
    required this.name,
  });
}

class TeacherStoryBuilder extends StatefulWidget {
  final List<StoryStudent> students;

  const TeacherStoryBuilder({
    super.key,
    required this.students,
  });

  @override
  State<TeacherStoryBuilder> createState() =>
      _TeacherStoryBuilderState();
}

class _TeacherStoryBuilderState extends State<TeacherStoryBuilder> {
  final StoryService _storyService = StoryService();
  final SupabaseClient _supabase = Supabase.instance.client;

  StoryStudent? selectedStudent;
  String? selectedReadingLevel;
  String? selectedInterest;

  bool isLoading = false;

  Map<String, dynamic>? story;

  final List<String> readingLevels = [
    "Pre-K",
    "Kindergarten",
    "1st Grade",
    "2nd Grade",
    "3rd Grade",
  ];

  final List<String> interests = [
    "Animals",
    "Dinosaurs",
    "Princesses",
    "Space",
    "Sports",
    "Superheroes",
    "Ocean",
    "Cars",
    "Magic",
    "Adventure",
  ];

  Future<void> generateStory() async {
    if (selectedStudent == null ||
        selectedReadingLevel == null ||
        selectedInterest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete all selections."),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
      story = null;
    });

    try {
      final result = await _storyService.generateStory(
        student: selectedStudent!.name,
        readingLevel: selectedReadingLevel!,
        interest: selectedInterest!,
      );

      final teacherId = _supabase.auth.currentUser?.id;

      if (teacherId == null) {
        throw Exception("No teacher is currently signed in.");
      }

      await _supabase.from('generated_stories').insert({
        'teacher_id': teacherId,
        'student_id': selectedStudent!.id,
        'title': result['title']?.toString() ?? '',
        'story': result['story']?.toString() ?? '',
        'reading_level': selectedReadingLevel,
        'interest': selectedInterest,
        'dolch_words': result['dolchWords'] ?? [],
        'questions': result['questions'] ?? [],
      });

      if (!mounted) return;

      setState(() {
        story = result;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to generate story: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildStudentDropdown({
    required List<StoryStudent> students,
    required StoryStudent? value,
    required ValueChanged<StoryStudent?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DropdownButtonFormField<StoryStudent>(
        value: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: "Student",
          border: OutlineInputBorder(),
        ),
        items: students
            .map(
              (student) => DropdownMenuItem<StoryStudent>(
            value: student,
            child: Text(
              student.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: students.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget buildDropdown({
    required String title,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget buildStoryCard() {
    if (story == null) {
      return const SizedBox.shrink();
    }

    final List<dynamic> dolchWords =
        story!["dolchWords"] as List<dynamic>? ?? [];

    final List<dynamic> questions =
        story!["questions"] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              story!["title"]?.toString() ?? "",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              story!["story"]?.toString() ?? "",
            ),
            const SizedBox(height: 24),
            const Text(
              "Dolch Words",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dolchWords
                  .map(
                    (word) => Chip(
                  label: Text(word.toString()),
                ),
              )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              "Comprehension Questions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...questions.map(
                  (question) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "• ${question.toString()}",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, StoryStudent> uniqueStudents = {
      for (final student in widget.students)
        if (student.name.trim().isNotEmpty) student.id: student,
    };

    final List<StoryStudent> students =
    uniqueStudents.values.toList()
      ..sort(
            (a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      );

    return TeacherBaseScaffold(
      pageTitle: "AI Story Builder",
      currentIndex: 0,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (students.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "No students are currently available.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Add a student from the teacher dashboard before generating a story.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              buildStudentDropdown(
                students: students,
                value: selectedStudent,
                onChanged: (value) {
                  setState(() {
                    selectedStudent = value;
                  });
                },
              ),
              buildDropdown(
                title: "Reading Level",
                items: readingLevels,
                value: selectedReadingLevel,
                onChanged: (value) {
                  setState(() {
                    selectedReadingLevel = value;
                  });
                },
              ),
              buildDropdown(
                title: "Interest",
                items: interests,
                value: selectedInterest,
                onChanged: (value) {
                  setState(() {
                    selectedInterest = value;
                  });
                },
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : generateStory,
                  child: isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text("Generate Story"),
                ),
              ),
              buildStoryCard(),
            ],
          ],
        ),
      ),
    );
  }
}