package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Verse represents a single verse with metadata
type Verse struct {
	ID        int
	Testament int
	Book      string
	Chapter   int
	VerseNum  int
	Text      string
	Title     string
	Refs      []string
}

func main() {
	verses := make(map[int]*Verse)

	// 1. Parse biblia.sql (Verses)
	fmt.Println("Parsing biblia.sql...")
	parseVerses("biblia.sql", verses)

	// 2. Parse biblia_titluri.sql (Titles)
	fmt.Println("Parsing biblia_titluri.sql...")
	parseTitles("biblia_titluri.sql", verses)

	// 3. Parse biblia_trimiteri.sql (References)
	fmt.Println("Parsing biblia_trimiteri.sql...")
	parseRefs("biblia_trimiteri.sql", verses)

	// 4. Output to bible_data.txt
	fmt.Println("Writing bible_data.txt...")
	writeOutput("bible_data.txt", verses)

	fmt.Println("Done!")
}

func parseVerses(filename string, verses map[int]*Verse) {
	content, err := os.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	// Regex to match: (id, testament, 'Book', Chapter, Verse, 'Text')
	// Updated to handle both '' and \. as escapes
	re := regexp.MustCompile(`\((\d+),(\d+),'([^']+)',(\d+),(\d+),'((?:[^'\\]|''|\\.)*)'\)`)

	matches := re.FindAllStringSubmatch(string(content), -1)
	for _, match := range matches {
		id, _ := strconv.Atoi(match[1])
		testament, _ := strconv.Atoi(match[2])
		book := match[3]
		chapter, _ := strconv.Atoi(match[4])
		verseNum, _ := strconv.Atoi(match[5])
		text := match[6]

		verses[id] = &Verse{
			ID:        id,
			Testament: testament,
			Book:      book,
			Chapter:   chapter,
			VerseNum:  verseNum,
			Text:      text,
		}
	}
}

func parseTitles(filename string, verses map[int]*Verse) {
	content, err := os.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	re := regexp.MustCompile(`\(\d+,(\d+),'((?:[^'\\]|''|\\.)*)'\)`)
	matches := re.FindAllStringSubmatch(string(content), -1)
	for _, match := range matches {
		idVerset, _ := strconv.Atoi(match[1])
		title := match[2]

		if v, ok := verses[idVerset]; ok {
			v.Title = title
		}
	}
}

func parseRefs(filename string, verses map[int]*Verse) {
	content, err := os.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	re := regexp.MustCompile(`\(\d+,(\d+),\d+,'((?:[^'\\]|''|\\.)*)'\)`)
	matches := re.FindAllStringSubmatch(string(content), -1)
	for _, match := range matches {
		idVerset, _ := strconv.Atoi(match[1])
		ref := match[2]

		if v, ok := verses[idVerset]; ok {
			v.Refs = append(v.Refs, ref)
		}
	}
}

func writeOutput(filename string, verses map[int]*Verse) {
	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	writer := bufio.NewWriter(file)

	// Sort by ID to ensure order.
	// Assuming ID order corresponds to Book/Chapter/Verse order.
	var ids []int
	for id := range verses {
		ids = append(ids, id)
	}
	sort.Ints(ids)

	currentBook := ""
	currentChapter := 0

	for _, id := range ids {
		v := verses[id]

		if v.Book != currentBook {
			// New Book Header
			writer.WriteString(fmt.Sprintf("# %s\n", v.Book))
			currentBook = v.Book
			currentChapter = 0 // Reset chapter on new book
		}

		if v.Chapter != currentChapter {
			// New Chapter Header
			writer.WriteString(fmt.Sprintf("= %d\n", v.Chapter))
			currentChapter = v.Chapter
		}

		if v.Title != "" {
			writer.WriteString(fmt.Sprintf("T %s\n", v.Title))
		}

		// Verse: VerseNum Text
		writer.WriteString(fmt.Sprintf("%d %s\n", v.VerseNum, v.Text))

		if len(v.Refs) > 0 {
			writer.WriteString(fmt.Sprintf("R %s\n", strings.Join(v.Refs, ";")))
		}
	}
	writer.Flush()
}
