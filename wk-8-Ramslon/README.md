# Library Database Management System

A comprehensive SQL database schema for managing a library system, including books, members, authors, categories, and loan tracking.

## Database Schema Overview

This database system is designed to manage a library's core operations with the following main entities:

### Tables

#### 1. Members
Stores information about library members.
- `member_id` (Primary Key): Unique identifier for each member
- `first_name`: Member's first name
- `last_name`: Member's last name  
- `email`: Unique email address
- `phone`: Contact phone number
- `join_date`: Date when member joined the library

#### 2. Categories
Organizes books into different categories.
- `category_id` (Primary Key): Unique identifier for each category
- `category_name`: Name of the book category (e.g., Fiction, Science, History)

#### 3. Books
Contains information about all books in the library.
- `book_id` (Primary Key): Unique identifier for each book
- `title`: Book title
- `isbn`: International Standard Book Number (unique)
- `published_year`: Year the book was published
- `category_id` (Foreign Key): References Categories table
- `copies_available`: Number of copies available for loan

#### 4. Authors
Stores author information.
- `author_id` (Primary Key): Unique identifier for each author
- `first_name`: Author's first name
- `last_name`: Author's last name

#### 5. BookAuthors (Junction Table)
Handles the many-to-many relationship between books and authors.
- `book_id` (Foreign Key): References Books table
- `author_id` (Foreign Key): References Authors table
- Composite Primary Key: (book_id, author_id)

#### 6. Loans
Tracks book borrowing and returns.
- `loan_id` (Primary Key): Unique identifier for each loan
- `member_id` (Foreign Key): References Members table
- `book_id` (Foreign Key): References Books table
- `loan_date`: Date when book was borrowed
- `due_date`: Date when book should be returned
- `return_date`: Actual return date (NULL if not returned)

## Database Features

- **Referential Integrity**: Foreign key constraints ensure data consistency
- **Cascade Deletions**: Automatic cleanup of related records when books or authors are deleted
- **Default Values**: Automatic setting of join dates and loan dates
- **Unique Constraints**: Prevents duplicate emails, ISBNs, and category names
- **Many-to-Many Relationships**: Supports books with multiple authors

## Setup Instructions

### Prerequisites
- MySQL 5.7+ or MariaDB 10.2+
- MySQL client or database management tool

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ramslon/Data-Analysis.git
   cd Data-Analysis
   ```

2. **Connect to your MySQL server**
   ```bash
   mysql -u your_username -p
   ```

3. **Execute the database script**
   ```sql
   source library_db.sql;
   ```
   
   Or copy and paste the contents of `library_db.sql` into your MySQL client.

## Usage Examples

### Sample Data Insertion

```sql
-- Add categories
INSERT INTO Categories (category_name) VALUES 
('Fiction'), ('Science'), ('History'), ('Technology');

-- Add authors
INSERT INTO Authors (first_name, last_name) VALUES 
('George', 'Orwell'), ('Isaac', 'Asimov'), ('Jane', 'Austen');

-- Add books
INSERT INTO Books (title, isbn, published_year, category_id, copies_available) VALUES 
('1984', '978-0-452-28423-4', 1949, 1, 3),
('Foundation', '978-0-553-29335-0', 1951, 2, 2),
('Pride and Prejudice', '978-0-14-143951-8', 1813, 1, 4);

-- Link books to authors
INSERT INTO BookAuthors (book_id, author_id) VALUES 
(1, 1), (2, 2), (3, 3);

-- Add members
INSERT INTO Members (first_name, last_name, email, phone) VALUES 
('John', 'Doe', 'john.doe@email.com', '555-0123'),
('Jane', 'Smith', 'jane.smith@email.com', '555-0124');

-- Record a loan
INSERT INTO Loans (member_id, book_id, due_date) VALUES 
(1, 1, DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY));
```

### Common Queries

#### Find all books by a specific author
```sql
SELECT b.title, b.isbn, b.published_year 
FROM Books b
JOIN BookAuthors ba ON b.book_id = ba.book_id
JOIN Authors a ON ba.author_id = a.author_id
WHERE a.first_name = 'George' AND a.last_name = 'Orwell';
```

#### Check overdue books
```sql
SELECT m.first_name, m.last_name, b.title, l.due_date
FROM Loans l
JOIN Members m ON l.member_id = m.member_id
JOIN Books b ON l.book_id = b.book_id
WHERE l.return_date IS NULL AND l.due_date < CURRENT_DATE;
```

#### View available books by category
```sql
SELECT c.category_name, b.title, b.copies_available
FROM Books b
JOIN Categories c ON b.category_id = c.category_id
WHERE b.copies_available > 0
ORDER BY c.category_name, b.title;
```

## Database Relationships

```
Members (1) ----< (M) Loans (M) >---- (1) Books
                                              |
                                              | (M)
                                              |
                                              v
                                         Categories (1)
                                              
Books (M) ----< BookAuthors >---- (M) Authors
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Contact

For questions or suggestions, please open an issue or contact the repository owner.