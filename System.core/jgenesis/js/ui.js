export function showUi() {
    // document.getElementById("loading-text").remove();
    // document.getElementById("header-text").classList.remove("hidden");
    // document.getElementById("jgenesis").classList.remove("hidden");
    // document.getElementById("footer").hidden = false;
}

/**
 * @param fullscreen {boolean}
 */
export function setFullscreen(fullscreen) {
    // document.querySelectorAll(".hide-fullscreen").forEach((element) => {
    //     element.hidden = fullscreen;
    // });
}

export function focusCanvas() {
    document.querySelector("canvas").focus();
}

const configIds = ["smsgg-config", "genesis-config", "snes-config", "gba-config"];

/**
 * @param id {string}
 */
function hideAllConfigsExcept(id) {
    // for (const configId of configIds) {
    //     document.getElementById(configId).hidden = configId !== id;
    // }

    // document.getElementById("supported-files-info").hidden = true;
    // document.getElementById("input-config").hidden = false;
}

/**
 * @param inputNames {string[]}
 * @param inputKeys {string[]}
 */
function renderInputs(inputNames, inputKeys) {
    // const listNode = document.createElement("ul");

    // for (const [i, name] of inputNames.entries()) {
    //     const key = inputKeys[i];

    //     const span = document.createElement("span");
    //     span.innerText = `${name}: `;

    //     const button = document.createElement("input");
    //     button.classList.add("input-configure");
    //     button.setAttribute("name", "input-configure");
    //     button.setAttribute("type", "button");
    //     button.setAttribute("value", key);
    //     button.setAttribute("data-name", name);

    //     if (window.inputClickListener) {
    //         button.addEventListener("click", window.inputClickListener);
    //     }

    //     const listItem = document.createElement("li");
    //     listItem.appendChild(span);
    //     listItem.appendChild(button);
    //     listNode.appendChild(listItem);
    // }

    // const controls = document.getElementById("controls");
    // controls.innerHTML = "";
    // controls.appendChild(listNode);
}

/**
 * @param inputNames {string[]}
 * @param inputKeys {string[]}
 */
export function showSmsGgConfig(inputNames, inputKeys) {
    // hideAllConfigsExcept("smsgg-config");
    // renderInputs(inputNames, inputKeys);
}

/**
 * @param inputNames {string[]}
 * @param inputKeys {string[]}
 */
export function showGenesisConfig(inputNames, inputKeys) {
    // hideAllConfigsExcept("genesis-config");
    // renderInputs(inputNames, inputKeys);
}

/**
 * @param inputNames {string[]}
 * @param inputKeys {string[]}
 */
export function showSnesConfig(inputNames, inputKeys) {
    // hideAllConfigsExcept("snes-config");
    // renderInputs(inputNames, inputKeys);
}

/**
 * @param inputNames {string[]}
 * @param inputKeys {string[]}
 */
export function showGbaConfig(inputNames, inputKeys) {
    // hideAllConfigsExcept("gba-config");
    // renderInputs(inputNames, inputKeys);
}

/**
 * @param visible {boolean}
 */
export function setCursorVisible(visible) {
    // let canvas = document.querySelector("canvas");
    // if (visible) {
    //     canvas.classList.remove("cursor-hidden");
    // } else {
    //     canvas.classList.add("cursor-hidden");
    // }
}

/**
 * @param romTitle {string}
 */
export function setRomTitle(romTitle) {
    // document.getElementById("jgenesis-rom-title").innerText = romTitle;
}

/**
 * @param saveUiEnabled {boolean}
 */
export function setSaveUiEnabled(saveUiEnabled) {
    // let saveButtons = document.getElementsByClassName("save-button");
    // if (saveUiEnabled) {
    //     for (let i = 0; i < saveButtons.length; i++) {
    //         saveButtons[i].removeAttribute("disabled");
    //     }
    // } else {
    //     for (let i = 0; i < saveButtons.length; i++) {
    //         saveButtons[i].setAttribute("disabled", "");
    //     }
    // }
}

export function beforeInputConfigure() {
    // for (const element of document.getElementsByClassName("input-configure")) {
    //     element.disabled = true;
    // }

    // document.getElementById("jgenesis-wasm").classList.add("darken");
}

/**
 * @param name {string}
 * @param key {string}
 */
export function afterInputConfigure(name, key) {
    // for (const element of document.getElementsByClassName("input-configure")) {
    //     element.disabled = false;

    //     if (element.getAttribute("data-name") === name) {
    //         element.setAttribute("value", key);
    //     }
    // }

    // document.getElementById("jgenesis-wasm").classList.remove("darken");
}

/**
 * @param key {string}
 * @return {string | null}
 */
export function localStorageGet(key) {
    return localStorage.getItem(key);
}

/**
 * @param key {string}
 * @param value {string}
 */
export function localStorageSet(key, value) {
    localStorage.setItem(key, value);
}

/**
 * Save state 完成回调
 * @param slot {number}
 * @param success {boolean}
 */
export function onSaveStateComplete(slot, success) {
    // 通知 Swift/iOS 端 save state 完成
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        window.webkit.messageHandlers.jgenesis.postMessage({
            type: 'saveStateComplete',
            slot: slot,
            success: success
        });
    }
    console.log(`Save state to slot ${slot}: ${success ? 'success' : 'failed'}`);
}

/**
 * Load state 完成回调
 * @param slot {number}
 * @param success {boolean}
 */
export function onLoadStateComplete(slot, success) {
    // 通知 Swift/iOS 端 load state 完成
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        window.webkit.messageHandlers.jgenesis.postMessage({
            type: 'loadStateComplete',
            slot: slot,
            success: success
        });
    }
    console.log(`Load state from slot ${slot}: ${success ? 'success' : 'failed'}`);
}

/**
 * 导出 save state 完成回调
 * @param data {Uint8Array | null}
 * @param success {boolean}
 */
export function onExportSaveStateComplete(data, success) {
    // 通知 Swift/iOS 端导出完成
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        if (success && data) {
            // 将 Uint8Array 转换为 Base64 字符串以便传输
            const base64 = uint8ArrayToBase64(data);
            window.webkit.messageHandlers.jgenesis.postMessage({
                type: 'exportSaveStateComplete',
                success: true,
                data: base64,
                size: data.length
            });
        } else {
            window.webkit.messageHandlers.jgenesis.postMessage({
                type: 'exportSaveStateComplete',
                success: false,
                data: null,
                size: 0
            });
        }
    }
    console.log(`Export save state: ${success ? 'success, size=' + (data ? data.length : 0) + ' bytes' : 'failed'}`);
}

/**
 * 导入 save state 完成回调
 * @param success {boolean}
 * @param error {string | null}
 */
export function onImportSaveStateComplete(success, error) {
    // 通知 Swift/iOS 端导入完成
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        window.webkit.messageHandlers.jgenesis.postMessage({
            type: 'importSaveStateComplete',
            success: success,
            error: error
        });
    }
    console.log(`Import save state: ${success ? 'success' : 'failed - ' + error}`);
}

/**
 * 将 Uint8Array 转换为 Base64 字符串
 * @param uint8Array {Uint8Array}
 * @returns {string}
 */
function uint8ArrayToBase64(uint8Array) {
    let binary = '';
    const len = uint8Array.byteLength;
    for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(uint8Array[i]);
    }
    return btoa(binary);
}

/**
 * 将 Base64 字符串转换为 Uint8Array
 * @param base64 {string}
 * @returns {Uint8Array}
 */
function base64ToUint8Array(base64) {
    const binary = atob(base64);
    const len = binary.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
}

// 暴露给全局以便 Swift 调用（仅在主线程中执行，AudioWorklet 环境没有 window）
if (typeof window !== 'undefined') {
    window.base64ToUint8Array = base64ToUint8Array;
}

/**
 * 暂停状态变化回调
 * @param paused {boolean}
 */
export function onPauseStateChanged(paused) {
    // 通知 Swift/iOS 端暂停状态变化
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        window.webkit.messageHandlers.jgenesis.postMessage({
            type: 'pauseStateChanged',
            paused: paused
        });
    }
    console.log(`Emulator ${paused ? 'paused' : 'resumed'}`);
}

/**
 * SRAM 存档写入通知
 * @param data {Uint8Array} 存档数据
 */
export function onSaveDataWritten(data) {
    // 通知 Swift/iOS 端 SRAM 存档已写入
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jgenesis) {
        // 将 Uint8Array 转换为 Base64 字符串以便传输
        const base64 = uint8ArrayToBase64(data);
        window.webkit.messageHandlers.jgenesis.postMessage({
            type: 'saveDataWritten',
            data: base64,
            size: data.length
        });
    }
    console.log(`SRAM save data written: size=${data.length} bytes`);
}