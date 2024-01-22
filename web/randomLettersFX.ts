// Copyright (C) 2023 Calin Radoni. Licensed under the MIT license (https://opensource.org/license/mit/).

/**
 * Random letters effect
 *
 * Version 1.4.0
 *
 * @remarks
 * The newest version of this script should be in the
 * {@link https://github.com/CalinRadoni/Scripts} repository.
 *
 * @example CodePen
 * See the {@link https://codepen.io/CalinRadoni/pen/BabdBre} pen.
 *
 * @example Usage
 * ```html
 * <h1 id="titleText"></h1>
 * ```
 * ```ts
 * const fxText = new RandomLetterFX("titleText", "CalinRadoni.github.io");
 * fxText.begin();
 * ```
 *
 * @example Usage Astro
 * ```html
 * <h1 id="titleText"></h1>
 * ```
 * ```astro
 * <script>
 *   import { RandomLetterFX } from "../scripts/textfx";
 *   const fxText = new RandomLetterFX("titleText", "CalinRadoni.github.io");
 *   fxText.begin();
 * </script>
 * ```
 */

export { RandomLetterFX };

interface Letter {
    char: string;
    steps: number;
}

class RandomLetterFX {
    private alphabet: string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789~!@#$%^&*()_-+=-?{[]}<>";
    private delay: number = 50;
    private minRandomSteps: number = 2;
    private maxRandomSteps: number = 0;

    private displayLength: number = 0;
    private letters: Array<Letter> = [];
    private output: string = "";

    private elemId: string = "";

    /**
     * @param id - the id of the HTML element where the text will be rendered
     * @param text - the text that will be rendered
     */
    constructor(id: string, text: string) {
        this.elemId = id;

        for (let i = 0; i < text.length; ++i) {
            this.letters.push({
                char: text.charAt(i),
                steps: this.minRandomSteps
            });
        }
    }

    /**
     * Start the effect
     */
    begin() {
        if (this.letters.length > 0) {
            this.maxRandomSteps = this.letters.length + 1;
            this.buildSteps();
            this.displayLength = 1;
            this.run();
        }
    }

    /**
     * Build the steps used for random number of letters
     *
     * @remark
     * Set the {@link RandomLetterFX.maxRandomSteps} before calling this function
     */
    private buildSteps() {
        for (let i = 0; i < this.letters.length; ++i) {
            this.letters[i].steps = this.minRandomSteps +
                (Math.floor(
                    (this.maxRandomSteps - this.minRandomSteps) * Math.random()));
        }
    }

    /**
     * Calls the {@link RandomLetterFX.frame} function and, if the animation is not over,
     * schedules another frame processing after {@link RandomLetterFX.delay} milliseconds.
     */
    private run() {
        setTimeout(() => {
            if (!this.frame()) {
                this.run();
            }
        }, this.delay);
    }

    private charToEntity(ch: string): string {
        let str: string = "";
        switch (ch) {
            case "<": { str = "&lt;"; break;}
            case ">": { str = "&gt;"; break;}
            case "&": { str = "&amp;"; break;}
            case "\"": { str = "&quot;"; break;}
            case "'": { str = "&apos;"; break;}
            default: { str = ch; break; }
        }
        return str;
    }

    /**
     * Create a new "frame" and set the content of the destination HTML element.
     *
     * @returns true when animation is over
     */
    private frame(): boolean {
        let done = true;
        this.output = "";
        for (let ci = 0; ci < this.displayLength; ++ci) {
            if (this.letters[ci].steps > 0) {
                let randomPos = Math.floor(this.alphabet.length * Math.random());
                let ch = this.charToEntity(this.alphabet.charAt(randomPos));
                let str = `<span style="opacity: 0.7;">${ch}</span>`
                this.output += str;
                --this.letters[ci].steps;
                done = false;
            }
            else {
                this.output += this.charToEntity(this.letters[ci].char);
            }
        }
        if(this.displayLength < this.letters.length) {
            ++this.displayLength;
        }

        let outField = document.getElementById(this.elemId);
        if (outField !== null) {
            outField.innerHTML = this.output;
        }

        return done;
    }
}
