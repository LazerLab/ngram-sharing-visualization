from flask import Flask, render_template, request, url_for, jsonify
import time
import os

app = Flask(__name__)


ngram_filenames = os.listdir('static/data/30/')


@app.route('/')
def root():
    return render_template('index.html',
                           ngrams=ngram_filenames)

if __name__ == '__main__':
    app.run(debug=True)
