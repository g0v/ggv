# Development Hypothesis client with PDF.js

1. clone and setup the `pdf.js-hypothes.is` location in the `Makefile`

```
cd ../../
git clone git@github.com:hypothesis/pdf.js-hypothes.is.git
cd ggv/develop_with_pdf
```

in your favorite editor:

```
PDF_VIEWER_SRC=../../pdf.js-hypothes.is
```

2. clone and start Hypothesis client in another session

```
git clone git@github.com:hypothesis/client.git
cd ./client
npm install
gulp watch
```

3. copy and patch `viewer.html`

```
make
```

4. serve with any static http server

```
serve
```
