package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type Verse struct {
	ID       int
	Book     string
	Chapter  int
	VerseNum int
	Text     string
	Title    string
	Refs     []string
}

func main() {
	if len(os.Args) < 2 {
		printUsage()
		return
	}

	command := os.Args[1]
	verses, err := loadBible("../bible_data.txt.xz")
	if err != nil {
		fmt.Printf("Error loading bible: %v\n", err)
		os.Exit(1)
	}

	switch command {
	case "list":
		listBooks(verses)
	case "read":
		if len(os.Args) < 4 {
			fmt.Println("Usage: bible_reader read <Book> <Chapter> [Verse]")
			return
		}
		book := os.Args[2]
		chapter, _ := strconv.Atoi(os.Args[3])
		verseNum := 0
		if len(os.Args) >= 5 {
			verseNum, _ = strconv.Atoi(os.Args[4])
		}
		readBible(verses, book, chapter, verseNum)
	case "search":
		if len(os.Args) < 3 {
			fmt.Println("Usage: bible_reader search <Query>")
			return
		}
		query := strings.Join(os.Args[2:], " ")
		searchBible(verses, query)
	default:
		printUsage()
	}
}

func printUsage() {
	fmt.Println("Bible Reader (Floppy Edition)")
	fmt.Println("Commands:")
	fmt.Println("  list                          List all books")
	fmt.Println("  read <Book> <Chapter> [Verse] Read a chapter or specific verse")
	fmt.Println("  search <query>                Search for text")
	fmt.Println("\nExample: bible_reader read Ioan 3 16")
}

func loadBible(filename string) ([]*Verse, error) {
	// Decompress using xz -d -c
	cmd := exec.Command("xz", "-d", "-c", filename)
	output, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}

	var verses []*Verse
	scanner := bufio.NewScanner(output)

	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	var currentBook string
	var currentChapter int
	var currentTitle string
	var lastVerse *Verse

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "# ") {
			currentBook = strings.TrimPrefix(line, "# ")
			currentChapter = 0
			currentTitle = ""
			lastVerse = nil
			continue
		}

		if strings.HasPrefix(line, "= ") {
			currentChapter, _ = strconv.Atoi(strings.TrimPrefix(line, "= "))
			currentTitle = ""
			lastVerse = nil // Clear last verse context on new chapter? usually refs follow verse.
			// But titles precede verse.
			continue
		}

		if strings.HasPrefix(line, "T ") {
			currentTitle = strings.TrimPrefix(line, "T ")
			continue
		}

		if strings.HasPrefix(line, "R ") {
			if lastVerse != nil {
				refs := strings.TrimPrefix(line, "R ")
				lastVerse.Refs = strings.Split(refs, ";")
			}
			continue
		}

		// Otherwise it's a verse: "VerseNum Text"
		parts := strings.SplitN(line, " ", 2)
		if len(parts) < 2 {
			continue
		}
		verseNum, _ := strconv.Atoi(parts[0])
		text := parts[1]

		v := &Verse{
			ID:       len(verses) + 1, // Generate ID or don't need it strictly
			Book:     currentBook,
			Chapter:  currentChapter,
			VerseNum: verseNum,
			Text:     text,
			Title:    currentTitle,
		}
		verses = append(verses, v)
		lastVerse = v
		currentTitle = "" // Reset title after using it
	}

	return verses, nil
}

func listBooks(verses []*Verse) {
	seen := make(map[string]bool)
	var books []string

	for _, v := range verses {
		if !seen[v.Book] {
			if len(books) > 0 && books[len(books)-1] == v.Book {
				continue // Already added (assuming sorted input)
			}
			// Just in case input is not perfectly sorted by book occurrence
			if !seen[v.Book] {
				books = append(books, v.Book)
				seen[v.Book] = true
			}
		}
	}

	fmt.Println("Books available:")
	for _, b := range books {
		fmt.Println("- " + b)
	}
}

const (
	ColorReset = "\033[0m"
	ColorRed   = "\033[31m"
)

func readBible(verses []*Verse, book string, chapter, verseNum int) {
	found := false
	for _, v := range verses {
		if strings.EqualFold(v.Book, book) && v.Chapter == chapter {
			if verseNum == 0 || v.VerseNum == verseNum {
				if v.Title != "" {
					fmt.Printf("\n### %s ###\n", v.Title)
				}
				fmt.Printf("[%d:%d] %s", v.Chapter, v.VerseNum, formatText(v.Text))
				if len(v.Refs) > 0 {
					fmt.Printf(" (%s)", strings.Join(v.Refs, ", "))
				}
				fmt.Println()
				found = true
			}
		}
	}
	if !found {
		fmt.Println("No verses found.")
	}
}

func searchBible(verses []*Verse, query string) {
	count := 0
	// Normalize query to lower case and remove diacritics
	queryNorm := normalize(query)

	for _, v := range verses {
		// Normalize text for search comparison (keep original for display)
		if strings.Contains(normalize(v.Text), queryNorm) {
			fmt.Printf("%s %d:%d - %s\n", v.Book, v.Chapter, v.VerseNum, formatText(v.Text))
			count++
			if count > 50 {
				fmt.Println("... too many results, type more specific query")
				return
			}
		}
	}
	if count == 0 {
		fmt.Println("No results found.")
	}
}

func normalize(s string) string {
	s = strings.ToLower(s)
	// Replace Romanian diacritics with base characters
	r := strings.NewReplacer(
		"ă", "a", "â", "a",
		"î", "i",
		"ş", "s", "ș", "s", // Handle both cedilla and comma
		"ţ", "t", "ț", "t",
	)
	return r.Replace(s)
}

func formatText(text string) string {
	// Replace <span class=\'Isus\'>Text</span> with Red Text
	// Handle various escaped quotes that might appear
	text = strings.ReplaceAll(text, "<span class=\\'Isus\\'>", ColorRed)
	text = strings.ReplaceAll(text, "<span class='Isus'>", ColorRed)
	text = strings.ReplaceAll(text, "</span>", ColorReset)

	// Clean up any double empty resets or such if needed, but simple replacement should work
	// Also depending on data, might need to handle other HTML tags if they exist?
	// For now focus on Isus.
	return text
}
