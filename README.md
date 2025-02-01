
# Reflect-Anki-Sync

## Project Description

Th
is project is designed to generate an Anki importable text file from a Reflect.app CSV dump. Reflect.app is a note-taking application that provides end-to-end encryption for user data, ensuring privacy and security.

## Usage

1. Export your notes from Reflect.app as a CSV file.
2. Run the script provided in this repository to convert the CSV file into an Anki importable text file.
3. Import the generated text file into Anki to create your flashcards.

## Writing Notes on Reflect App for Anki Import

To ensure your notes on the Reflect app are correctly parsed and imported into Anki, follow these guidelines:

### Tagging Patterns
Use specific tags to identify the type of note. The supported tags are:
- `#spaced`
- `#reversed`
- `#type`
- `#cloze`

### Question and Answer Format
- For `#spaced`, `#reversed`, and `#type` tags, the first bullet point will be treated as the question, and the subsequent bullet points will be treated as answers.
- For `#cloze` tags, only the first bullet point will be used, and it should contain the cloze deletion format (e.g., `{{c1::cloze}}`).

### Example Note Structure
- **Spaced Repetition:**
  - #spaced
    - This is a question
    - This is a first line of answer
    - This is a second line of answer

- **Reversed Card:**
  - #reversed
    - This is a question
    - This is a first line of answer
    - This is a second line of answer

- **Type in the Answer:**
  - #type
    - This is a question
    - This is an answer

- **Cloze Deletion:**
  - #cloze
    - This is a {{c1::cloze}} question.


## Limitations

Due to the end-to-end encryption implemented by Reflect.app, it is not possible to build a more automated solution for accessing and processing the data. The current [Reflect.app API](https://reflect.academy/api) does not support direct information access (it's Append Only except for the limited information), which is why manual export and conversion are necessary.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
