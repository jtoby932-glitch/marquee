#!/usr/bin/env python3
"""Writes MARQUEE/Resources/demo-library.json: about 300 real titles with a
believable mix of statuses, ratings and dates. Only used with -demoData, which
seeds an in-memory store for screenshots and tests. Deterministic (seeded).
"""
import json
import random
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
rng = random.Random(1207)

# (tmdb id, title, year, director, runtime, genres)
FILMS = [
    (693134, "Dune: Part Two", 2024, "Denis Villeneuve", 166, "Sci-fi,Adventure"),
    (438631, "Dune", 2021, "Denis Villeneuve", 155, "Sci-fi,Adventure"),
    (872585, "Oppenheimer", 2023, "Christopher Nolan", 180, "Drama,History"),
    (346698, "Barbie", 2023, "Greta Gerwig", 114, "Comedy,Fantasy"),
    (238, "The Godfather", 1972, "Francis Ford Coppola", 175, "Crime,Drama"),
    (680, "Pulp Fiction", 1994, "Quentin Tarantino", 154, "Crime,Thriller"),
    (550, "Fight Club", 1999, "David Fincher", 139, "Drama"),
    (603, "The Matrix", 1999, "Lana Wachowski", 136, "Action,Sci-fi"),
    (27205, "Inception", 2010, "Christopher Nolan", 148, "Action,Sci-fi"),
    (157336, "Interstellar", 2014, "Christopher Nolan", 169, "Sci-fi,Drama"),
    (496243, "Parasite", 2019, "Bong Joon-ho", 133, "Thriller,Drama"),
    (129, "Spirited Away", 2001, "Hayao Miyazaki", 125, "Animation,Fantasy"),
    (155, "The Dark Knight", 2008, "Christopher Nolan", 152, "Action,Crime"),
    (545611, "Everything Everywhere All at Once", 2022, "Daniel Kwan", 139, "Action,Comedy"),
    (666277, "Past Lives", 2023, "Celine Song", 106, "Drama,Romance"),
    (329865, "Arrival", 2016, "Denis Villeneuve", 116, "Sci-fi,Drama"),
    (335984, "Blade Runner 2049", 2017, "Denis Villeneuve", 164, "Sci-fi,Drama"),
    (76341, "Mad Max: Fury Road", 2015, "George Miller", 121, "Action,Adventure"),
    (313369, "La La Land", 2016, "Damien Chazelle", 128, "Romance,Music"),
    (244786, "Whiplash", 2014, "Damien Chazelle", 107, "Drama,Music"),
    (419430, "Get Out", 2017, "Jordan Peele", 104, "Horror,Mystery"),
    (152601, "Her", 2013, "Spike Jonze", 126, "Romance,Sci-fi"),
    (376867, "Moonlight", 2016, "Barry Jenkins", 111, "Drama"),
    (278, "The Shawshank Redemption", 1994, "Frank Darabont", 142, "Drama,Crime"),
    (194, "Amélie", 2001, "Jean-Pierre Jeunet", 122, "Comedy,Romance"),
    (346648, "Paddington 2", 2017, "Paul King", 104, "Comedy,Family"),
    (4638, "Hot Fuzz", 2007, "Edgar Wright", 121, "Comedy,Action"),
    (747, "Shaun of the Dead", 2004, "Edgar Wright", 99, "Comedy,Horror"),
    (391713, "Lady Bird", 2017, "Greta Gerwig", 94, "Comedy,Drama"),
    (531428, "Portrait of a Lady on Fire", 2019, "Céline Sciamma", 122, "Drama,Romance"),
    (965150, "Aftersun", 2022, "Charlotte Wells", 102, "Drama"),
    (120467, "The Grand Budapest Hotel", 2014, "Wes Anderson", 100, "Comedy,Drama"),
    (546554, "Knives Out", 2019, "Rian Johnson", 130, "Mystery,Comedy"),
    (361743, "Top Gun: Maverick", 2022, "Joseph Kosinski", 131, "Action,Drama"),
    (324857, "Spider-Man: Into the Spider-Verse", 2018, "Bob Persichetti", 117, "Animation,Action"),
    (792307, "Poor Things", 2023, "Yorgos Lanthimos", 141, "Sci-fi,Comedy"),
    (467244, "The Zone of Interest", 2023, "Jonathan Glazer", 105, "Drama,History"),
    (915935, "Anatomy of a Fall", 2023, "Justine Triet", 152, "Thriller,Drama"),
    (466420, "Killers of the Flower Moon", 2023, "Martin Scorsese", 206, "Crime,Drama"),
    (840430, "The Holdovers", 2023, "Alexander Payne", 133, "Comedy,Drama"),
    (64690, "Drive", 2011, "Nicolas Winding Refn", 100, "Crime,Drama"),
    (348, "Alien", 1979, "Ridley Scott", 117, "Horror,Sci-fi"),
    (578, "Jaws", 1975, "Steven Spielberg", 124, "Thriller,Adventure"),
    (105, "Back to the Future", 1985, "Robert Zemeckis", 116, "Adventure,Comedy"),
    (329, "Jurassic Park", 1993, "Steven Spielberg", 127, "Adventure,Sci-fi"),
    (862, "Toy Story", 1995, "John Lasseter", 81, "Animation,Family"),
    (10681, "WALL·E", 2008, "Andrew Stanton", 98, "Animation,Sci-fi"),
    (14160, "Up", 2009, "Pete Docter", 96, "Animation,Adventure"),
    (2062, "Ratatouille", 2007, "Brad Bird", 111, "Animation,Comedy"),
    (354912, "Coco", 2017, "Lee Unkrich", 105, "Animation,Family"),
    (346, "Seven Samurai", 1954, "Akira Kurosawa", 207, "Action,Drama"),
    (289, "Casablanca", 1942, "Michael Curtiz", 102, "Drama,Romance"),
    (426, "Vertigo", 1958, "Alfred Hitchcock", 128, "Mystery,Thriller"),
    (539, "Psycho", 1960, "Alfred Hitchcock", 109, "Horror,Thriller"),
    (62, "2001: A Space Odyssey", 1968, "Stanley Kubrick", 149, "Sci-fi,Mystery"),
    (28, "Apocalypse Now", 1979, "Francis Ford Coppola", 147, "War,Drama"),
    (103, "Taxi Driver", 1976, "Martin Scorsese", 114, "Crime,Drama"),
    (769, "Goodfellas", 1990, "Martin Scorsese", 145, "Crime,Drama"),
    (949, "Heat", 1995, "Michael Mann", 170, "Crime,Thriller"),
    (807, "Se7en", 1995, "David Fincher", 127, "Crime,Mystery"),
    (6977, "No Country for Old Men", 2007, "Joel Coen", 122, "Crime,Thriller"),
    (7345, "There Will Be Blood", 2007, "Paul Thomas Anderson", 158, "Drama"),
    (37799, "The Social Network", 2010, "David Fincher", 121, "Drama"),
    (1949, "Zodiac", 2007, "David Fincher", 157, "Crime,Mystery"),
    (210577, "Gone Girl", 2014, "David Fincher", 149, "Mystery,Thriller"),
    (146233, "Prisoners", 2013, "Denis Villeneuve", 153, "Thriller,Crime"),
    (273481, "Sicario", 2015, "Denis Villeneuve", 121, "Crime,Thriller"),
    (9693, "Children of Men", 2006, "Alfonso Cuarón", 109, "Sci-fi,Drama"),
    (1417, "Pan's Labyrinth", 2006, "Guillermo del Toro", 118, "Fantasy,War"),
    (843, "In the Mood for Love", 2000, "Wong Kar-wai", 98, "Drama,Romance"),
    (670, "Oldboy", 2003, "Park Chan-wook", 120, "Thriller,Mystery"),
    (11423, "Memories of Murder", 2003, "Bong Joon-ho", 131, "Crime,Drama"),
    (264660, "Ex Machina", 2015, "Alex Garland", 108, "Sci-fi,Drama"),
    (137113, "Edge of Tomorrow", 2014, "Doug Liman", 113, "Action,Sci-fi"),
    (120, "The Lord of the Rings: The Fellowship of the Ring", 2001, "Peter Jackson", 179, "Adventure,Fantasy"),
    (121, "The Lord of the Rings: The Two Towers", 2002, "Peter Jackson", 179, "Adventure,Fantasy"),
    (122, "The Lord of the Rings: The Return of the King", 2003, "Peter Jackson", 201, "Adventure,Fantasy"),
    (11, "Star Wars", 1977, "George Lucas", 121, "Adventure,Sci-fi"),
    (1891, "The Empire Strikes Back", 1980, "Irvin Kershner", 124, "Adventure,Sci-fi"),
    (85, "Raiders of the Lost Ark", 1981, "Steven Spielberg", 115, "Adventure,Action"),
    (280, "Terminator 2: Judgment Day", 1991, "James Cameron", 137, "Action,Sci-fi"),
    (679, "Aliens", 1986, "James Cameron", 137, "Action,Sci-fi"),
    (1091, "The Thing", 1982, "John Carpenter", 109, "Horror,Mystery"),
    (38, "Eternal Sunshine of the Spotless Mind", 2004, "Michel Gondry", 108, "Romance,Sci-fi"),
    (153, "Lost in Translation", 2003, "Sofia Coppola", 102, "Drama,Comedy"),
    (37165, "The Truman Show", 1998, "Peter Weir", 103, "Comedy,Drama"),
    (275, "Fargo", 1996, "Joel Coen", 98, "Crime,Thriller"),
    (115, "The Big Lebowski", 1998, "Joel Coen", 117, "Comedy,Crime"),
    (627, "Trainspotting", 1996, "Danny Boyle", 94, "Drama,Crime"),
    (279, "Amadeus", 1984, "Miloš Forman", 160, "Drama,History"),
    (76, "Before Sunrise", 1995, "Richard Linklater", 101, "Romance,Drama"),
    (80, "Before Sunset", 2004, "Richard Linklater", 80, "Romance,Drama"),
    (398818, "Call Me by Your Name", 2017, "Luca Guadagnino", 132, "Romance,Drama"),
    (375262, "The Favourite", 2018, "Yorgos Lanthimos", 120, "History,Comedy"),
    (400617, "Phantom Thread", 2017, "Paul Thomas Anderson", 131, "Drama,Romance"),
    (331482, "Little Women", 2019, "Greta Gerwig", 135, "Drama,Romance"),
    (505600, "Booksmart", 2019, "Olivia Wilde", 102, "Comedy"),
    (473033, "Uncut Gems", 2019, "Josh Safdie", 135, "Thriller,Crime"),
    (492188, "Marriage Story", 2019, "Noah Baumbach", 137, "Drama"),
    (817758, "Tár", 2022, "Todd Field", 158, "Drama,Music"),
    (674324, "The Banshees of Inisherin", 2022, "Martin McDonagh", 114, "Comedy,Drama"),
    (705996, "Decision to Leave", 2022, "Park Chan-wook", 139, "Mystery,Romance"),
    (762504, "Nope", 2022, "Jordan Peele", 130, "Horror,Sci-fi"),
    (414906, "The Batman", 2022, "Matt Reeves", 176, "Crime,Mystery"),
    (940721, "Godzilla Minus One", 2023, "Takashi Yamazaki", 125, "Sci-fi,Action"),
    (976893, "Perfect Days", 2023, "Wim Wenders", 124, "Drama"),
    (986280, "Fallen Leaves", 2023, "Aki Kaurismäki", 81, "Comedy,Romance"),
    (937287, "Challengers", 2024, "Luca Guadagnino", 131, "Drama,Romance"),
    (786892, "Furiosa: A Mad Max Saga", 2024, "George Miller", 149, "Action,Adventure"),
    (1022789, "Inside Out 2", 2024, "Kelsey Mann", 97, "Animation,Family"),
    (402431, "Wicked", 2024, "Jon M. Chu", 161, "Fantasy,Music"),
    (974576, "Conclave", 2024, "Edward Berger", 120, "Thriller,Drama"),
    (1064213, "Anora", 2024, "Sean Baker", 139, "Comedy,Drama"),
    (549509, "The Brutalist", 2024, "Brady Corbet", 215, "Drama,History"),
    (933260, "The Substance", 2024, "Coralie Fargeat", 141, "Horror,Sci-fi"),
    (98, "Gladiator", 2000, "Ridley Scott", 155, "Action,Drama"),
    (930564, "Saltburn", 2023, "Emerald Fennell", 131, "Comedy,Thriller"),
    (353081, "Mission: Impossible – Fallout", 2018, "Christopher McQuarrie", 148, "Action,Thriller"),
    (37724, "Skyfall", 2012, "Sam Mendes", 143, "Action,Thriller"),
    (36557, "Casino Royale", 2006, "Martin Campbell", 144, "Action,Thriller"),
    (116149, "Paddington", 2014, "Paul King", 95, "Comedy,Family"),
    (1124, "The Prestige", 2006, "Christopher Nolan", 130, "Mystery,Drama"),
    (77, "Memento", 2000, "Christopher Nolan", 113, "Mystery,Thriller"),
    (424, "Schindler's List", 1993, "Steven Spielberg", 195, "Drama,History"),
    (857, "Saving Private Ryan", 1998, "Steven Spielberg", 169, "War,Drama"),
    (13, "Forrest Gump", 1994, "Robert Zemeckis", 142, "Comedy,Drama"),
    (274, "The Silence of the Lambs", 1991, "Jonathan Demme", 118, "Crime,Thriller"),
    (4935, "Howl's Moving Castle", 2004, "Hayao Miyazaki", 119, "Animation,Fantasy"),
    (128, "Princess Mononoke", 1997, "Hayao Miyazaki", 134, "Animation,Fantasy"),
    (8392, "My Neighbour Totoro", 1988, "Hayao Miyazaki", 86, "Animation,Family"),
    (508442, "Soul", 2020, "Pete Docter", 100, "Animation,Comedy"),
    (530915, "1917", 2019, "Sam Mendes", 119, "War,Drama"),
    (581734, "Nomadland", 2020, "Chloé Zhao", 108, "Drama"),
    (614917, "King Richard", 2021, "Reinaldo Marcus Green", 145, "Drama"),
    (776503, "CODA", 2021, "Sian Heder", 112, "Drama,Music"),
    (1008042, "Talk to Me", 2023, "Danny Philippou", 95, "Horror"),
    (1029575, "The Fall Guy", 2024, "David Leitch", 126, "Action,Comedy"),
    (1184918, "The Wild Robot", 2024, "Chris Sanders", 102, "Animation,Sci-fi"),
    (945961, "Alien: Romulus", 2024, "Fede Álvarez", 119, "Horror,Sci-fi"),
    (1100782, "Smile 2", 2024, "Parker Finn", 127, "Horror,Mystery"),
    (762441, "A Quiet Place: Day One", 2024, "Michael Sarnoski", 99, "Horror,Sci-fi"),
]

# (tmdb id, title, year, creator, episode runtime, genres)
SHOWS = [
    (1396, "Breaking Bad", 2008, "Vince Gilligan", 47, "Drama,Crime"),
    (136315, "The Bear", 2022, "Christopher Storer", 32, "Comedy,Drama"),
    (95396, "Severance", 2022, "Dan Erickson", 52, "Drama,Mystery"),
    (76331, "Succession", 2018, "Jesse Armstrong", 62, "Drama"),
    (67070, "Fleabag", 2016, "Phoebe Waller-Bridge", 26, "Comedy,Drama"),
    (60059, "Better Call Saul", 2015, "Vince Gilligan", 50, "Crime,Drama"),
    (66732, "Stranger Things", 2016, "The Duffer Brothers", 55, "Sci-fi & fantasy,Mystery"),
    (95480, "Slow Horses", 2022, "Will Smith", 48, "Drama,Crime"),
    (126308, "Shōgun", 2024, "Rachel Kondo", 58, "Drama,War & politics"),
    (83867, "Andor", 2022, "Tony Gilroy", 45, "Sci-fi & fantasy,Drama"),
    (100088, "The Last of Us", 2023, "Craig Mazin", 56, "Drama,Sci-fi & fantasy"),
    (60574, "Peaky Blinders", 2013, "Steven Knight", 58, "Drama,Crime"),
    (19885, "Sherlock", 2010, "Mark Gatiss", 88, "Crime,Mystery"),
    (70523, "Dark", 2017, "Baran bo Odar", 55, "Sci-fi & fantasy,Mystery"),
    (87108, "Chernobyl", 2019, "Craig Mazin", 65, "Drama,History"),
    (46648, "True Detective", 2014, "Nic Pizzolatto", 58, "Crime,Mystery"),
    (1104, "Mad Men", 2007, "Matthew Weiner", 47, "Drama"),
    (1398, "The Sopranos", 1999, "David Chase", 55, "Crime,Drama"),
    (1438, "The Wire", 2002, "David Simon", 58, "Crime,Drama"),
    (1920, "Twin Peaks", 1990, "David Lynch", 47, "Mystery,Drama"),
    (65495, "Atlanta", 2016, "Donald Glover", 30, "Comedy,Drama"),
    (62560, "Mr. Robot", 2015, "Sam Esmail", 49, "Crime,Drama"),
    (97546, "Ted Lasso", 2020, "Bill Lawrence", 38, "Comedy,Drama"),
    (89905, "Normal People", 2020, "Sally Rooney", 30, "Drama,Romance"),
    (241554, "Baby Reindeer", 2024, "Richard Gadd", 33, "Drama"),
    (94605, "Arcane", 2021, "Christian Linke", 40, "Animation,Sci-fi & fantasy"),
    (111803, "The White Lotus", 2021, "Mike White", 58, "Comedy,Drama"),
    (107113, "Only Murders in the Building", 2021, "Steve Martin", 32, "Comedy,Mystery"),
    (125935, "Abbott Elementary", 2021, "Quinta Brunson", 22, "Comedy"),
    (105248, "Hacks", 2021, "Lucia Aniello", 30, "Comedy,Drama"),
    (76479, "The Boys", 2019, "Eric Kripke", 60, "Action & adventure,Sci-fi & fantasy"),
    (94997, "House of the Dragon", 2022, "Ryan Condal", 63, "Drama,Sci-fi & fantasy"),
    (106379, "Fallout", 2024, "Jonathan Nolan", 60, "Drama,Sci-fi & fantasy"),
    (113988, "Industry", 2020, "Mickey Down", 55, "Drama"),
    (1399, "Game of Thrones", 2011, "David Benioff", 57, "Drama,Sci-fi & fantasy"),
    (2316, "The Office", 2005, "Greg Daniels", 22, "Comedy"),
    (1668, "Friends", 1994, "Marta Kauffman", 22, "Comedy"),
    (65494, "The Crown", 2016, "Peter Morgan", 58, "Drama,History"),
    (82856, "The Mandalorian", 2019, "Jon Favreau", 38, "Sci-fi & fantasy,Action & adventure"),
    (84958, "Loki", 2021, "Michael Waldron", 50, "Drama,Sci-fi & fantasy"),
    (63247, "Westworld", 2016, "Jonathan Nolan", 62, "Sci-fi & fantasy,Western"),
    (42009, "Black Mirror", 2011, "Charlie Brooker", 60, "Drama,Sci-fi & fantasy"),
    (2190, "South Park", 1997, "Trey Parker", 22, "Animation,Comedy"),
    (456, "The Simpsons", 1989, "Matt Groening", 22, "Animation,Comedy"),
    (1408, "House", 2004, "David Shore", 44, "Drama,Mystery"),
    (4614, "NCIS", 2003, "Donald P. Bellisario", 43, "Crime,Drama"),
    (71912, "The Witcher", 2019, "Lauren Schmidt Hissrich", 60, "Drama,Sci-fi & fantasy"),
    (93405, "Squid Game", 2021, "Hwang Dong-hyuk", 55, "Action & adventure,Mystery"),
    (119051, "Wednesday", 2022, "Alfred Gough", 49, "Comedy,Mystery"),
    (84773, "The Lord of the Rings: The Rings of Power", 2022, "J. D. Payne", 66, "Drama,Sci-fi & fantasy"),
    (154385, "Bluey", 2018, "Joe Brumm", 7, "Animation,Kids"),
    (85552, "Euphoria", 2019, "Sam Levinson", 55, "Drama"),
    (73586, "Yellowstone", 2018, "Taylor Sheridan", 50, "Western,Drama"),
]

# (title, year, author, pages, genres)
BOOKS = [
    ("Dune", 1965, "Frank Herbert", 658, "Science fiction"),
    ("Tomorrow, and Tomorrow, and Tomorrow", 2022, "Gabrielle Zevin", 416, "Fiction"),
    ("Project Hail Mary", 2021, "Andy Weir", 496, "Science fiction"),
    ("The Secret History", 1992, "Donna Tartt", 559, "Fiction,Mystery"),
    ("Normal People", 2018, "Sally Rooney", 266, "Fiction,Romance"),
    ("Klara and the Sun", 2021, "Kazuo Ishiguro", 303, "Science fiction"),
    ("The Remains of the Day", 1989, "Kazuo Ishiguro", 258, "Fiction"),
    ("Never Let Me Go", 2005, "Kazuo Ishiguro", 288, "Science fiction"),
    ("Piranesi", 2020, "Susanna Clarke", 272, "Fantasy"),
    ("Jonathan Strange & Mr Norrell", 2004, "Susanna Clarke", 1006, "Fantasy"),
    ("The Hobbit", 1937, "J. R. R. Tolkien", 310, "Fantasy"),
    ("The Fellowship of the Ring", 1954, "J. R. R. Tolkien", 423, "Fantasy"),
    ("Nineteen Eighty-Four", 1949, "George Orwell", 328, "Fiction,Dystopia"),
    ("Animal Farm", 1945, "George Orwell", 112, "Fiction"),
    ("Pride and Prejudice", 1813, "Jane Austen", 432, "Romance,Classics"),
    ("Emma", 1815, "Jane Austen", 474, "Romance,Classics"),
    ("Jane Eyre", 1847, "Charlotte Brontë", 532, "Classics,Romance"),
    ("Wuthering Heights", 1847, "Emily Brontë", 416, "Classics"),
    ("Great Expectations", 1861, "Charles Dickens", 544, "Classics"),
    ("Middlemarch", 1871, "George Eliot", 880, "Classics"),
    ("Frankenstein", 1818, "Mary Shelley", 280, "Classics,Horror"),
    ("Dracula", 1897, "Bram Stoker", 418, "Classics,Horror"),
    ("The Great Gatsby", 1925, "F. Scott Fitzgerald", 180, "Classics"),
    ("To Kill a Mockingbird", 1960, "Harper Lee", 281, "Classics"),
    ("Brave New World", 1932, "Aldous Huxley", 311, "Science fiction,Dystopia"),
    ("The Handmaid's Tale", 1985, "Margaret Atwood", 311, "Fiction,Dystopia"),
    ("Station Eleven", 2014, "Emily St. John Mandel", 333, "Science fiction"),
    ("Sea of Tranquility", 2022, "Emily St. John Mandel", 255, "Science fiction"),
    ("The Road", 2006, "Cormac McCarthy", 287, "Fiction"),
    ("Blood Meridian", 1985, "Cormac McCarthy", 351, "Fiction,Western"),
    ("Beloved", 1987, "Toni Morrison", 324, "Fiction"),
    ("The Bell Jar", 1963, "Sylvia Plath", 288, "Fiction,Classics"),
    ("Atonement", 2001, "Ian McEwan", 371, "Fiction"),
    ("Wolf Hall", 2009, "Hilary Mantel", 653, "Historical fiction"),
    ("Bring Up the Bodies", 2012, "Hilary Mantel", 432, "Historical fiction"),
    ("The Mirror & the Light", 2020, "Hilary Mantel", 883, "Historical fiction"),
    ("Life of Pi", 2001, "Yann Martel", 319, "Fiction,Adventure"),
    ("The Kite Runner", 2003, "Khaled Hosseini", 371, "Fiction"),
    ("The Book Thief", 2005, "Markus Zusak", 552, "Historical fiction"),
    ("The Night Circus", 2011, "Erin Morgenstern", 387, "Fantasy"),
    ("The Name of the Wind", 2007, "Patrick Rothfuss", 662, "Fantasy"),
    ("A Wizard of Earthsea", 1968, "Ursula K. Le Guin", 183, "Fantasy"),
    ("The Left Hand of Darkness", 1969, "Ursula K. Le Guin", 304, "Science fiction"),
    ("Foundation", 1951, "Isaac Asimov", 255, "Science fiction"),
    ("Neuromancer", 1984, "William Gibson", 271, "Science fiction"),
    ("Hyperion", 1989, "Dan Simmons", 482, "Science fiction"),
    ("The Three-Body Problem", 2008, "Liu Cixin", 400, "Science fiction"),
    ("Children of Time", 2015, "Adrian Tchaikovsky", 600, "Science fiction"),
    ("The Martian", 2011, "Andy Weir", 369, "Science fiction"),
    ("Ready Player One", 2011, "Ernest Cline", 374, "Science fiction"),
    ("Good Omens", 1990, "Terry Pratchett", 412, "Fantasy,Comedy"),
    ("Guards! Guards!", 1989, "Terry Pratchett", 355, "Fantasy,Comedy"),
    ("Small Gods", 1992, "Terry Pratchett", 384, "Fantasy,Comedy"),
    ("The Hitchhiker's Guide to the Galaxy", 1979, "Douglas Adams", 224, "Science fiction,Comedy"),
    ("Harry Potter and the Philosopher's Stone", 1997, "J. K. Rowling", 223, "Fantasy"),
    ("His Dark Materials: Northern Lights", 1995, "Philip Pullman", 399, "Fantasy"),
    ("The Lion, the Witch and the Wardrobe", 1950, "C. S. Lewis", 208, "Fantasy"),
    ("Circe", 2018, "Madeline Miller", 393, "Fantasy,Mythology"),
    ("The Song of Achilles", 2011, "Madeline Miller", 378, "Fantasy,Mythology"),
    ("Babel", 2022, "R. F. Kuang", 545, "Fantasy"),
    ("Yellowface", 2023, "R. F. Kuang", 336, "Fiction"),
    ("Fourth Wing", 2023, "Rebecca Yarros", 517, "Fantasy,Romance"),
    ("Lessons in Chemistry", 2022, "Bonnie Garmus", 390, "Fiction"),
    ("The Seven Husbands of Evelyn Hugo", 2017, "Taylor Jenkins Reid", 389, "Fiction"),
    ("Daisy Jones & The Six", 2019, "Taylor Jenkins Reid", 355, "Fiction,Music"),
    ("Where the Crawdads Sing", 2018, "Delia Owens", 368, "Fiction,Mystery"),
    ("The Thursday Murder Club", 2020, "Richard Osman", 382, "Mystery"),
    ("Gone Girl", 2012, "Gillian Flynn", 419, "Mystery,Thriller"),
    ("The Girl with the Dragon Tattoo", 2005, "Stieg Larsson", 465, "Mystery,Thriller"),
    ("And Then There Were None", 1939, "Agatha Christie", 272, "Mystery"),
    ("Murder on the Orient Express", 1934, "Agatha Christie", 256, "Mystery"),
    ("The Hound of the Baskervilles", 1902, "Arthur Conan Doyle", 256, "Mystery,Classics"),
    ("Rebecca", 1938, "Daphne du Maurier", 449, "Mystery,Classics"),
    ("Slow Horses", 2010, "Mick Herron", 336, "Thriller"),
    ("Tinker Tailor Soldier Spy", 1974, "John le Carré", 400, "Thriller"),
    ("Sapiens", 2011, "Yuval Noah Harari", 443, "Non-fiction,History"),
    ("Thinking, Fast and Slow", 2011, "Daniel Kahneman", 499, "Non-fiction,Psychology"),
    ("Educated", 2018, "Tara Westover", 334, "Memoir"),
    ("Becoming", 2018, "Michelle Obama", 448, "Memoir"),
    ("H Is for Hawk", 2014, "Helen Macdonald", 300, "Memoir,Nature"),
    ("Atomic Habits", 2018, "James Clear", 320, "Non-fiction"),
    ("The Body", 2019, "Bill Bryson", 450, "Non-fiction,Science"),
    ("A Short History of Nearly Everything", 2003, "Bill Bryson", 544, "Non-fiction,Science"),
    ("Notes from a Small Island", 1995, "Bill Bryson", 324, "Travel"),
    ("Into Thin Air", 1997, "Jon Krakauer", 368, "Non-fiction,Adventure"),
    ("Born a Crime", 2016, "Trevor Noah", 304, "Memoir"),
    ("Shuggie Bain", 2020, "Douglas Stuart", 430, "Fiction"),
    ("Hamnet", 2020, "Maggie O'Farrell", 372, "Historical fiction"),
    ("Small Things Like These", 2021, "Claire Keegan", 128, "Fiction"),
    ("Demon Copperhead", 2022, "Barbara Kingsolver", 548, "Fiction"),
    ("Intermezzo", 2024, "Sally Rooney", 448, "Fiction"),
    ("James", 2024, "Percival Everett", 302, "Fiction"),
    ("Orbital", 2023, "Samantha Harvey", 207, "Fiction"),
    ("The Midnight Library", 2020, "Matt Haig", 304, "Fiction,Fantasy"),
    ("Anxious People", 2019, "Fredrik Backman", 352, "Fiction"),
    ("A Little Life", 2015, "Hanya Yanagihara", 720, "Fiction"),
    ("Pachinko", 2017, "Min Jin Lee", 490, "Historical fiction"),
    ("Cloud Atlas", 2004, "David Mitchell", 509, "Fiction,Science fiction"),
    ("The Bone Clocks", 2014, "David Mitchell", 595, "Fantasy"),
    ("Mexican Gothic", 2020, "Silvia Moreno-Garcia", 301, "Horror"),
]

OVERVIEWS = {
    "Dune: Part Two": "Paul Atreides unites with the Fremen while on a path of revenge against the conspirators who destroyed his family.",
    "Dune": "A boy with a remarkable destiny travels to the most dangerous planet in the universe to secure his people's future.",
    "Severance": "Office workers whose memories have been surgically divided between their work and personal lives begin to uncover the truth.",
    "Project Hail Mary": "A lone astronaut wakes on a spacecraft with no memory and must save the Earth from extinction.",
}


def ol_key(title):
    return "OL" + str(zlib.crc32(title.encode()) % 90000000 + 10000000) + "W"


def pick_status(kind):
    r = rng.random()
    if kind == "film":
        return "finished" if r < 0.68 else ("wantTo" if r < 0.95 else "dropped")
    if kind == "show":
        return "inProgress" if r < 0.35 else ("finished" if r < 0.7 else ("wantTo" if r < 0.9 else ("paused" if r < 0.96 else "dropped")))
    return "finished" if r < 0.5 else ("wantTo" if r < 0.8 else ("inProgress" if r < 0.94 else "paused"))


def rating(status):
    if status != "finished" or rng.random() < 0.12:
        return None
    return rng.choices(range(3, 11), weights=[1, 2, 3, 6, 9, 12, 9, 6])[0]


records = []


def add(uid, kind, name, year, creator, genres, runtime=None, pages=None):
    status = pick_status(kind)
    added = rng.randint(3, 900)
    finished = rng.randint(1, added) if status == "finished" else None
    current = None
    if kind == "book" and status in ("inProgress", "paused") and pages:
        current = rng.randint(int(pages * 0.1), int(pages * 0.85))
    records.append({
        "uid": uid, "kind": kind, "name": name, "year": year, "creators": [creator],
        "genres": genres.split(","), "runtime": runtime, "pages": pages, "status": status,
        "rating": rating(status), "addedDaysAgo": added, "finishedDaysAgo": finished,
        "currentPage": current, "overview": OVERVIEWS.get(name),
    })


for tid, name, year, director, runtime, genres in FILMS:
    add(f"tmdb-movie-{tid}", "film", name, year, director, genres, runtime=runtime)
for tid, name, year, creator, runtime, genres in SHOWS:
    add(f"tmdb-tv-{tid}", "show", name, year, creator, genres, runtime=runtime)
for name, year, author, pages, genres in BOOKS:
    uid = "ol-OL893415W" if name == "Dune" else f"ol-{ol_key(name)}"
    add(uid, "book", name, year, author, genres, pages=pages)

# Make the hero items reliable for screenshots.
for r in records:
    if r["name"] in ("Dune: Part Two", "Past Lives", "Aftersun"):
        r.update(status="finished", rating=9 if r["name"] != "Aftersun" else 10, finishedDaysAgo=12, addedDaysAgo=40)
    if r["name"] in ("Severance", "The Bear", "Slow Horses"):
        r.update(status="inProgress", addedDaysAgo=5)
    if r["name"] in ("Project Hail Mary", "Piranesi"):
        r.update(status="inProgress", currentPage=int(r["pages"] * 0.42), addedDaysAgo=2, rating=None, finishedDaysAgo=None)
    if r["name"] in ("Conclave", "Anora", "The Brutalist", "Perfect Days"):
        r.update(status="wantTo", addedDaysAgo=1, rating=None, finishedDaysAgo=None)

out = ROOT / "MARQUEE" / "Resources" / "demo-library.json"
out.write_text(json.dumps(records, ensure_ascii=False, indent=1) + "\n")
print(f"{len(records)} demo titles: {sum(r['kind']=='film' for r in records)} films, "
      f"{sum(r['kind']=='show' for r in records)} shows, {sum(r['kind']=='book' for r in records)} books")
