// Copyright (C) 2023 Calin Radoni. Licensed under the MIT license (https://opensource.org/license/mit/).

/**
 * Random letters effect
 *
 * Version 1.0.0
 *
 * @remarks
 * This newest version of this script should be in the
 * {@link https://github.com/CalinRadoni/Scripts} repository.
 *
 * @example Usage
 * ```html
 * <h1 id="titleText"></h1>
 * ```
 * ```ts
 * let fxText = new RandomLetterFX("titleText", "CalinRadoni.github.io");
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
 *   let fxText = new RandomLetterFX("titleText", "CalinRadoni.github.io");
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
    private maxRandomSteps: number = 22;

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
                steps: this.minRandomSteps +
                        (Math.floor(
                            (this.maxRandomSteps - this.minRandomSteps) * Math.random())
                        )
            });
        }
    }

    /**
     * Start the effect
     */
    begin() {
        if (this.letters.length > 0) {
            this.displayLength = 1;
            this.maxRandomSteps = this.letters.length + 1;
            this.run();
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
                this.output += this.alphabet.charAt(randomPos);
                --this.letters[ci].steps;
                done = false;
            }
            else {
                this.output += this.letters[ci].char;
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
