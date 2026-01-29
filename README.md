# aero-dhbw 💨

A lightweight template for theses at DHBW Ravensburg.
Although, it can be customized to allow for use at other universities.
There are two thoughts behind the template:
1. Providing everything you need for simple papers that do not require specific styling setups
2. Being lightweight and easy to extend for papers that require more complex setups (for people who like extending their templates themselves)

Importing and using the template is pretty straight-forward, especially with previous Typst experience.

Note: The template doesn't support multiple authors.
If I find the time in the future (and someone requests it), I'll add support for multiple authors.

## Configuration Options

**title**: Title of your project

**project**: (DHBW-specific) Official name of the project, e.g. T1000

**project-type**: Type of the project, e.g. seminar thesis or bachelor thesis

**author**: Name of the author / your name

**course**: Name of your course, e.g. Electrical Engineering

**mat-number**: Your student ID, at the DHBW, should be a 6-digit number

**course-acronym**: Abbreviated form of your course name, should be three to four letters followed by two numbers

**start-date**: Starting date of the project

**end-date**: End date of the project

**supervisor**: Name of your supervisor for the project at your company

**university-supervisor**: Name of your professor that is supervising the project, mostly relevant for the bachelor thesis

**company**: Name of your employer

**company-location**: City of your employer

**university**: Name of your university

**university-logo**: Path to the image of your university's logo

**company-logo**: Path to the image of your company's logo

**confidentiality-notice**: Path to the image/PDF of your confidentiality notice, mostly relevant for theses made at the company

**place-of-authorship**: Name of the city where you completed the project, relevant for the declaration of authorship

**path-to-abstract**: Path to the Typst file containing your abstract

**acronym-list**: Dictionary of acronyms you intend to use. I'd recommend not creating your own, but using `glossary-list` in `acronyms.typ`

**bib**: Path to the `.bib` file containing your citations

**bib-style**: Bibliography syntax style, defaults to IEEE.

**citation-style**: Citation syntax style, defaults to IEEE. Tip: if you are looking for the dialect of IEEE commonly used in Engineering, use `alphanumeric`

**font**: Font for the paper, defaults to Typst's default font `Libertinus Serif`

**text-lang**: Abbreviation of the language used in the paper, relevant for the bibliography, figures, the titlepage and the declaration of authorship. At the moment, only English (`"en"`) and German (`"de"`) are supported.

**outline-style**: Style of the generated outlines. Two styles are supported: The default Typst style (`"typst"`) and the default style.

**margins**: Amount of margin to be applied to the document, defaults to 2.5cm (DHBW Ravensburg guideline)

**leading-spaces**: Amount of space between lines, defaults to 1.5em (DHBW Ravensburg guideline)

**text-size**: Size of text in pt, defaults to 12pt (DHBW Ravensburg guideline)

**par-spacing**: Amount of space between paragraphs, defaults to 2em

**figure-gap-above**: Amount of space between a figure and the paragraph above it, defaults to 1em

**figure-gap-under**: Amount of space between a figure and the paragraph under it, defaults to 1em

**table-caption-position**: Position of the table captions, defaults to bottom. Note: For the bachelor thesis at the DHBW Ravensburg, guidelines demand it to be above the table. In this case, use the option `"top"`.

**heading-name-as-supplement**: Option to use the name of a chapter when referencing it in text.
Example:
```typ
= Overview of Cloud Architecture <intro>

As you can see in @intro

// If heading-name-as-supplement is set to false this will resolve to:
As you can see in Section 2.

// If heading-name-as-supplement is set to true:
As you can see in Overview of Cloud Architecture.
```

**path-to-annex**: Path to the Typst file containing the annex

**used-ai**: A dictionary with the names of used AI models as keys and the description of how they were used as values. Displays a table in the annex with this information (required by the DHBW guidelines)


## Tips

Some tips on how to use this template optimally.

### Use acronyms in your paper

- Define some acronyms in `acronyms.typ` to use them for your paper
- Import glossy in your chapter files to make use of the defined acronyms with the following:
```typ
#import "@preview/glossy:0.9.0": *
```

- Now, you can use your acronyms by treating them like labels. Use `@` to reference them in your text.

**NOTE:**
Be careful when using acronyms in titles. 
Glossy will always display the first occurrence of an acronym in its long form + short form, e.g. "USA" will be displayed as `United States of America (USA)`.
Subsequent usage will use the abbreviation.

Since titles are displayed in the outline for the first time, the outline will be the first occurrence of the abbreviation.
This means, the long form of your acronym will only be displayed in the outline and never in your text.
This is not desired for scientific papers because you want your first in-text occurrence, not the first occurrence altogether, to display the long form.

You can circumvent this behavior by using glossy's builtin features.
When referencing an acronym in a title, e.g. "usa", do the following: `@usa:both`.
By adding `:both`, it will display the long form + short form, but will not count it towards in-text occurrences.
Check out [glossy](https://typst.app/universe/package/glossy) for more infos on how to use it.


### Define custom captions for outlines of figures/tables
- Decide what comes into the outlines for your figures by using the `pa-figure` command. But first, you need to import it into your chapters:
```typ
#import "@preview/aero-dhbw:0.1.0": pa-figure
```

- Afterwards, use `pa-figure` to differentiate between a long and a short caption:
    - **long**: This text will be displayed at the location of the figure
    - **short**: This text will be displayed in the outline of the figure

```typ
#pa-figure(
    image("some/image.png"),
    caption: (
        long: [This is a long caption that will show in the chapter],
        short: [This is a short caption that will show in the outline]
    ),
    supplement: [I can even put in different arguments for figure that will get parsed automatically!]
)
```

- Or, alternatively, just define one caption like you would usually and it will be used in both places
```typ
#pa-figure(
    image("some/image.png"),
    caption: [This caption will show up both in-text and in the outline.]
)
```
