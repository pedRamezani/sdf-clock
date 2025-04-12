import * as THREE from 'three';

let scene, camera, renderer, material, mesh, clock, uniforms, mouse, width, height;

let lastHours = -1;
let lastMinutes = -1;
let lastSeconds = -1;

init();
animate();

function init() {
    width = window.innerWidth;
    height = window.innerHeight;

    scene = new THREE.Scene();
    clock = new THREE.Clock();

    const canvas = document.getElementById('sdf');
    // Size will be set on first onWindowResize call
    renderer = new THREE.WebGLRenderer({ antialias: true, canvas });
    renderer.setPixelRatio( window.devicePixelRatio );
    renderer.autoClearColor = false;

    const frustumWidth = 2;
    const frustumHeight = 2;
    camera = new THREE.OrthographicCamera(
        frustumWidth / -2, 
        frustumWidth / 2, 
        frustumHeight / 2, 
        frustumHeight / -2, 
        .1, 1
    );

    uniforms = {
        resolution: {value: new THREE.Vector4()},
        delta: {value: 0.0},
        mouse: {value: new THREE.Vector4(0, 0, 0, 0)},
        hours: {
            value: {
                tens: 0,
                ones: 0,
            }
        },
        minutes: {
            value: {
                tens: 0,
                ones: 0,
            }
        },
        seconds: {
            value: {
                tens: 0,
                ones: 0,
            }
        }
    }

    onWindowResize();
    
    const geometry = new THREE.PlaneGeometry(2, 2);
    fetch('/shader/vertex.glsl')
        .then(response => response.text())
        .then(vertexShader => {
            fetch('/shader/fragment.glsl')
                .then(response => response.text())
                .then(fragmentShader => {
                    material = new THREE.ShaderMaterial({
                        uniforms: uniforms,
                        vertexShader: vertexShader,
                        fragmentShader: fragmentShader
                    });

                    mesh = new THREE.Mesh(geometry, material);
                    scene.add(mesh);

                    animate();
                });
        });

    mouseEvents();
    window.addEventListener('resize', onWindowResize, false);
}

function mouseEvents() {
    // Get mouse pos [0,1]^2 and scale, center it arround 0 to get [-1, 1]^2
    const offset = 0.5;
    mouse = new THREE.Vector2();
    
    function updateMousePosition(event) {
        let touch = undefined;
        if (event.touches) {
            touch = event.touches[0];
        }

        const pageX = event.pageX || touch.pageX;
        const pageY = event.pageY || touch.pageY;

        mouse.x = 2.0 * (pageX / width - offset);
        mouse.y = -2.0 * (pageY / height - offset);
    }

    let shouldBlockScroll = false;

    window.addEventListener('touchstart', function(event) {
        if (event.target.closest(canvas)) {
            shouldBlockScroll = true;
        }
    });

    window.addEventListener('touchend', function() {
        shouldBlockScroll = false;
    });

    ['mousemove', 'touchmove'].forEach(
        (eventName) => window.addEventListener(eventName, function(event) {
            if (shouldBlockScroll) {
                event.preventDefault();
            } else {
                updateMousePosition(event);
            }
        })
    );
}

function onWindowResize() {
    width = window.innerWidth;
    height = window.innerHeight;
    renderer.setSize(width, height);
    // camera.aspect = width / height;
    // camera.updateProjectionMatrix();

    const imageAspect = 1;
    let a1, a2;
    if(height / width > imageAspect) {
        a1 = (width / height) * imageAspect;
        a2 = 1;
    } else {
        a1 = 1;
        a2 = (height / width) / imageAspect;
    }

    uniforms.resolution.value.x = width;
    uniforms.resolution.value.y = height;
    uniforms.resolution.value.z = a1;
    uniforms.resolution.value.w = a2;
}

function createActiveSegments(digit) {
    // Create an array of 7 elements, all initially set to false
    let activeSegments = [false, false, false, false, false, false, false];

    // Set active segments based on the digit
    if (digit === 0) {
        activeSegments[0] = true;
        activeSegments[1] = true;
        activeSegments[2] = true;
        activeSegments[4] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    } else if (digit === 1) {
        activeSegments[2] = true;
        activeSegments[5] = true;
    } else if (digit === 2) {
        activeSegments[0] = true;
        activeSegments[2] = true;
        activeSegments[3] = true;
        activeSegments[4] = true;
        activeSegments[6] = true;
    } else if (digit === 3) {
        activeSegments[0] = true;
        activeSegments[2] = true;
        activeSegments[3] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    } else if (digit === 4) {
        activeSegments[1] = true;
        activeSegments[2] = true;
        activeSegments[3] = true;
        activeSegments[5] = true;
    } else if (digit === 5) {
        activeSegments[0] = true;
        activeSegments[1] = true;
        activeSegments[3] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    } else if (digit === 6) {
        activeSegments[0] = true;
        activeSegments[1] = true;
        activeSegments[3] = true;
        activeSegments[4] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    } else if (digit === 7) {
        activeSegments[0] = true;
        activeSegments[2] = true;
        activeSegments[5] = true;
    } else if (digit === 8) {
        activeSegments[0] = true;
        activeSegments[1] = true;
        activeSegments[2] = true;
        activeSegments[3] = true;
        activeSegments[4] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    } else if (digit === 9) {
        activeSegments[0] = true;
        activeSegments[1] = true;
        activeSegments[2] = true;
        activeSegments[3] = true;
        activeSegments[5] = true;
        activeSegments[6] = true;
    }

    return activeSegments;
}

function packBooleansToInt(booleans) {
    let packed = 0;
    for (let i = 0; i < booleans.length; i++) {
        if (booleans[i]) {
            packed |= (1 << i);
        }
    }
    return packed;
}

function animate() {
    uniforms.delta.value = clock.getElapsedTime();

    if (mouse) {
        uniforms.mouse.value = mouse;
    }

    const currentdate = new Date();
    if (currentdate) {
        // Get the hours, minutes, and seconds
        const hoursTens = Math.floor(currentdate.getHours() / 10);
        const hoursOnes = currentdate.getHours() % 10;
        const minutesTens = Math.floor(currentdate.getMinutes() / 10);
        const minutesOnes = currentdate.getMinutes() % 10;
        const secondsTens = Math.floor(currentdate.getSeconds() / 10);
        const secondsOnes = currentdate.getSeconds() % 10;

        // Check if the hours, minutes, or seconds have changed
        if (currentdate.getHours() !== lastHours) {
            uniforms.hours.value = {
                tens: packBooleansToInt(createActiveSegments(hoursTens)),
                ones: packBooleansToInt(createActiveSegments(hoursOnes))
            };
            lastHours = currentdate.getHours(); // Update last known hour
        }

        if (currentdate.getMinutes() !== lastMinutes) {
            uniforms.minutes.value = {
                tens: packBooleansToInt(createActiveSegments(minutesTens)),
                ones: packBooleansToInt(createActiveSegments(minutesOnes))
            };
            lastMinutes = currentdate.getMinutes(); // Update last known minute
        }

        if (currentdate.getSeconds() !== lastSeconds) {
            uniforms.seconds.value = {
                tens: packBooleansToInt(createActiveSegments(secondsTens)),
                ones: packBooleansToInt(createActiveSegments(secondsOnes))
            };
            lastSeconds = currentdate.getSeconds(); // Update last known second
        }
    }

    // Animation loop
    requestAnimationFrame(animate, 1000 / 30);
    renderer.render(scene, camera);
}