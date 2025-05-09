/**
 * @fileoverview Constant-time {@link Buffer} comparison utility compatible
 * with Node.js v18 through v24.  The implementation prefers the built-in
 * {@link crypto.timingSafeEqual} when available and falls back to a manual
 * XOR loop executed in constant time.
 *
 * The public API intentionally matches `buffer-equal-constant-time@1.x`
 * so that packages such as `jwa`/`jws` continue to work unchanged.
 * @module buffer-equal-constant-time
 */

'use strict';

const crypto = require('crypto');

/**
 * Compare two {@link Buffer Buffers} in constant time.
 *
 * @param {!Buffer} a The first buffer.
 * @param {!Buffer} b The second buffer.
 * @return {boolean} `true` if the buffers are equal; `false` otherwise.
 */
function bufferEqual(a, b) {
    // Guard against non-Buffer inputs (required for correctness).
    if (!Buffer.isBuffer(a) || !Buffer.isBuffer(b)) {
        return false;
    }

    // Length check is safe and avoids useless work if unequal.
    if (a.length !== b.length) {
        return false;
    }

    // Fast path: use the native constant-time helper when present.
    /* c8 ignore next 3 */
    if (typeof crypto.timingSafeEqual === 'function') {
        return crypto.timingSafeEqual(a, b);
    }

    // Fallback: manual XOR diff executed for the full length.
    let diff = 0;
    for (let i = 0; i < a.length; ++i) {
        diff |= a[i] ^ b[i];
    }
    return diff === 0;
}

/**
 * Monkey-patch {@link Buffer#equal} so legacy callers continue to work
 * without code changes. Use sparingly; mutating built-ins is discouraged.
 */
bufferEqual.install = () => {
    if (!bufferEqual.__origBufEqual) {
        bufferEqual.__origBufEqual = Buffer.prototype.equal;
    }

    /* eslint-disable no-extend-native */
    Buffer.prototype.equal = function equal(that) {
        return bufferEqual(this, that);
    };
    /* eslint-enable no-extend-native */
};

/**
 * Restore the original {@link Buffer#equal} implementation, if it was
 * replaced by {@link bufferEqual.install}.
 */
bufferEqual.restore = () => {
    /* eslint-disable no-extend-native */
    if (bufferEqual.__origBufEqual) {
        Buffer.prototype.equal = bufferEqual.__origBufEqual;
        delete bufferEqual.__origBufEqual;
    }
    /* eslint-enable no-extend-native */
};

module.exports = bufferEqual;
