library(tidyverse)
library(ggwordcloud)
library(tm)
library(RColorBrewer)

getwd()
#setwd("C:\\Users\\will.kent\\source\\repos\\R\\Text Mining\\Original Star Wars Scripts")

# Create manual stop words list
myStopwords <- c("can","got","like","oh","get","hey","just","come","need","want")

# Create function to clean Corpus text 
formatCorpus <- function(corpus){
  # Remove punctuation
  corpus <- tm_map(corpus, removePunctuation)
  # Make all words lower case
  corpus <- tm_map(corpus, content_transformer(tolower))
  # Remove digits
  corpus <- tm_map(corpus, removeNumbers)
  # Remove common words
  corpus <- tm_map(corpus, removeWords, stopwords("english"))
  corpus <- tm_map(corpus, removeWords, myStopwords)
  # Remove whitespace
  corpus <- tm_map(corpus, stripWhitespace)
  return(corpus)
}

# Create tokenizer function - for use with ngrams
tokenizer <-  function(x) unlist(lapply(ngrams(words(x), 2), paste, collapse = " "), use.names = FALSE)

# Create cosineSim fucntion
cosineSim <- function(x) as.dist(x%*%t(x) / (sqrt(rowSums(x^2) %*% t(rowSums(x^2)))))

# Load scripts into a data frame
ep4 <- read.table('.\\docs\\SW_EpisodeIV.txt')
ep5 <- read.table('.\\docs\\SW_EpisodeV.txt')
ep6 <- read.table('.\\docs\\SW_EpisodeVI.txt')

# Change dialouge from factor variable to character as it's not really a factor
ep4$dialogue <- as.character(ep4$dialogue)
ep5$dialogue <- as.character(ep5$dialogue)
ep6$dialogue <- as.character(ep6$dialogue)

# Change character from factor variable to character for cominbing datasets
ep4$character <- as.character(ep4$character)
ep5$character <- as.character(ep5$character)
ep6$character <- as.character(ep6$character)

# Create an extra field in each data frame to identify the episode
ep4$episode <- "ep4"
ep5$episode <- "ep5"
ep6$episode <- "ep6"

# Bind each data frame into a single data frame
trilogy <- rbind(ep4, ep5, ep6)

# Make Character and Episode factor variables
trilogy$character <- as.factor(trilogy$character)
trilogy$episode <- as.factor(trilogy$episode)

# Add word counts to data frame
trilogy$wordCount <- sapply(strsplit(trilogy$dialogue," "),length)

# If a character didn't speak in an episode make that explicit
vals <- expand.grid(character = unique(trilogy$character)
                    ,episode = unique(trilogy$episode))
trilogy <- merge(vals, trilogy, all = TRUE)
trilogy$wordCount[is.na(trilogy$wordCount)] <- 0

# Characters lines per movie
top_8_characters <- trilogy %>% 
  group_by(character) %>% 
  summarise(total = n()) %>% 
  arrange(desc(total)) %>% 
  top_n(8) %>% 
  select(character)

top_8 <- as.character(top_8_characters$character)

# Characters lines per movie across episodes
t <- trilogy %>% 
  filter(character %in% top_8) %>% 
  group_by(character, episode) %>% 
  summarise(total_dialouge = n()
            ,total_words = sum(wordCount)
            ,avg_words = ifelse(total_words == 0, 0, total_words/total_dialouge))

point_shapes <- c(15,16,17,18,19,0,1,2,3,4)

t %>% 
  ggplot(mapping = aes(x = episode, y = total_dialouge, colour = character, group = character)) +
  geom_line() +
  geom_point(aes(shape = character)) +
  scale_shape_manual(values = point_shapes) +
  theme_classic()

t %>% 
  ggplot(mapping = aes(x = episode, y = total_words, colour = character, group = character)) +
  geom_line() +
  geom_point(aes(shape = character)) +
  scale_shape_manual(values = point_shapes) +
  theme_classic()

t %>% 
  ggplot(mapping = aes(x = episode, y = avg_words, colour = character, group = character)) +
  geom_line() +
  geom_point(aes(shape = character)) +
  scale_shape_manual(values = point_shapes) +
  theme_classic()

#################
# Create Corpus #
#################
# Load text to corpus
words <- VCorpus(VectorSource(trilogy$dialogue))

# Clean Corpus
words <- formatCorpus(words)

###############
# Word Counts #
###############
dtm <- DocumentTermMatrix(words)

# Collapse matrix by summing over columns - returns counts for each word over all lines.
freq <- colSums(as.matrix(dtm))

# Length  returns the total number of distinct words used in the documents - 2804
length(freq)

# Order words in descending based on frequency
ord <- order(freq, decreasing = TRUE)

# View most frequently occurring terms
freq[head(ord)]

# View least frequently occurring terms
freq[tail(ord)]

# List most frequent terms - lowfreq filters terms with a total count of that value or higher
findFreqTerms(dtm, lowfreq = 100)

# Add terms and counts to a data frame 
df = data.frame(term = names(freq), occurrences = freq)

# Create histogram of most commonly used terms - ordered by frequency
bplot <- ggplot(subset(df, occurrences > 100), aes(reorder(term,occurrences), occurrences)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
bplot

bcloud <- df %>% 
  arrange(desc(occurrences)) %>% 
  mutate(angle = 90*(runif(nrow(df))>.6)) %>% 
  slice(1:50) %>% 
  ggplot(aes(label = term, size = occurrences, colour = occurrences, angle = angle)) +
  geom_text_wordcloud_area(shape = "circle") +
#  geom_text_wordcloud_area(
#    mask = png::readPNG(system.file("filelocation.png"
#                                    ,pacakge = "ggwordcloud"
#                                    ,mustWork = TRUE))
#    ,rm_outside = TRUE) + 
  scale_size(range = c(4, 16)) +
  scale_y_continuous(breaks = NULL) +
  scale_x_continuous(breaks = NULL) +
  scale_colour_gradient(low = "#0b77e3", high = "#ff6b0f") +
  theme(panel.background = element_blank())
bcloud

############
## Ngrams ##
############
# Find word sequences using ngrams - Do word sequences provide more insights
# create new Document Term Matrix for word sequencing
ngram_dtm <- DocumentTermMatrix(words, control = list(tokenize = tokenizer))

# Create matrix and sum sequence frequencies
ngram_freq <- colSums(as.matrix(ngram_dtm))

# Length gives the total number of word sequences - 9424
length(ngram_freq)

# Order matrix by frequency
ngram_ord <- order(ngram_freq, decreasing = TRUE)

# View most frequently occurring word sequences
ngram_freq[head(ngram_ord)]

# Create data frame for word sequences
df_ngram = data.frame(term = names(ngram_freq), occurrences = ngram_freq)

ncloud <- df_ngram %>% 
  arrange(desc(occurrences)) %>% 
  mutate(angle = 90*(runif(nrow(df_ngram))>.6)) %>% 
  slice(1:20) %>% 
  ggplot(aes(label = term, size = occurrences, colour = occurrences, angle = angle)) +
  geom_text_wordcloud_area(shape = "circle") +
  scale_size(range = c(4, 16)) +
  scale_y_continuous(breaks = NULL) +
  scale_x_continuous(breaks = NULL) +
  scale_colour_gradient(low = "#0b77e3", high = "#ff6b0f") +
  theme(panel.background = element_blank())
ncloud

############
## TF_IDF ##
############
# TF-IDF is a weighting method - terms that occur less often and more likely to be describe a document
# Create new dtm
tf_dtm <- DocumentTermMatrix(words, control = list(weighting = weightTfIdf))

# Add terms and sum weightings to matrix
tf_tot <- colSums(as.matrix(tf_dtm))

# Length gives the total number of terms - 2804
length(tf_tot)

# Order the matrix with summed weightings
tf_ord <- order(tf_tot, decreasing = TRUE)

# Inspect the most frequent terms
tf_tot[head(tf_ord)]

# Create a data frame with terms and the summed weights
df_tfidf = data.frame(term = names(tf_tot), weights = tf_tot)

# Create a wordcloud of important words based on weighting - seems elephants are important
tplot <- df_tfidf %>% 
  arrange(desc(weights)) %>% 
  mutate(angle = 90*(runif(nrow(df_tfidf))>.6)) %>% 
  slice(1:50) %>% 
  ggplot(aes(label = term, size = weights, colour = weights, angle = angle)) +
  geom_text_wordcloud_area() +
  scale_size(range = c(4, 16)) +
  scale_y_continuous(breaks = NULL) +
  scale_x_continuous(breaks = NULL) +
  scale_colour_gradient(low = "#0b77e3", high = "#ff6b0f") +
  theme(panel.background = element_blank())
tplot