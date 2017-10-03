require(jsonlite)
require(dplyr)
require(doSNOW)
require(doParallel)
require(lubridate)
# Define parameters
file <- "~/Desktop/Crypto-Markets.csv"
cpucore <- as.numeric(detectCores(all.tests = FALSE, logical = TRUE))
today <- gsub("-", "", today())
exchange_rate <- fromJSON("https://api.fixer.io/latest?base=USD")
AUD <- exchange_rate$rates$AUD
# Get USD to AUD exchange rate.
ptm <- proc.time()
# Retrieve listing of coin slugs to be used for searching.  range <- 1:50 #
# uncomment this if you only was a specific number
json <- "https://files.coinmarketcap.com/generated/search/quick_search.json"
coins <- jsonlite::read_json(json, simplifyVector = TRUE)
length <- as.numeric(length(coins$slug))
range <- 1:length
coins <- head(arrange(coins, rank), n = range)
symbol <- coins$slug
# Setup population of URLS we will scrape the history for
url <- paste0("https://coinmarketcap.com/currencies/", symbol, "/historical-data/?start=20130428&end=",
              today)
baseurl <- c(url)
urllist <- data.frame(url = baseurl, stringsAsFactors = FALSE)
attributes <- as.character(urllist$url)
# Start parallel processing
cluster = makeCluster(cpucore, type = "SOCK")
registerDoSNOW(cluster)
# Start scraping function to extract historical results table
abstracts <- function(attributes) {
  library(rvest)  #Scraping page
  page <- read_html(attributes)
  names <- page %>% html_nodes(css = ".col-sm-4 .text-large") %>% html_text(trim = TRUE) %>%
    replace(!nzchar(.), NA)
  nodes <- page %>% html_nodes(css = "table") %>% .[1] %>% html_table(fill = TRUE) %>%
    replace(!nzchar(.), NA)
  abstracts <- Reduce(rbind, nodes)
  # Cleaning up names
  names <- gsub("\\(||\\n|\\)|\\s\\s", "", names)
  abstracts$coin = strsplit(names, " ")[[1]][1]
  abstracts$coinname = strsplit(names, " ")[[1]][2]
  names(abstracts) <- c("date", "open", "high", "low", "close", "volume", "market",
                        "symbol", "coin")
  return(abstracts)
}
# Will combine data frames in parallel
results = foreach(i = range, .combine = rbind) %dopar% abstracts(attributes[i])
# Clean up
marketdata <- results
marketdata$volume <- gsub("\\,", "", marketdata$volume)
marketdata$market <- gsub("\\,", "", marketdata$market)
marketdata$volume <- gsub("-", "0", marketdata$volume)
marketdata$market <- gsub("-", "0", marketdata$market)
marketdata$date <- mdy(marketdata$date)
marketdata$open <- as.numeric(marketdata$open)
marketdata$close <- as.numeric(marketdata$close)
marketdata$high <- as.numeric(marketdata$high)
marketdata$low <- as.numeric(marketdata$low)
marketdata$symbol <- as.factor(marketdata$symbol)
marketdata$coin <- as.factor(marketdata$coin)
# Uncomment if you want converted into another currency marketdata$aud_open <-
# marketdata$open * AUD marketdata$aud_close <- marketdata$close * AUD
marketdata$variance <- ((marketdata$close - marketdata$open)/marketdata$close)  # percent variance between open and close rates
marketdata$volatility <- ((marketdata$high - marketdata$low)/marketdata$close)  # spread variance between days high, low and closing
write.csv(marketdata, file)
# Stop the amazing parallel processing power
stopCluster(cluster)
print(proc.time() - ptm)
