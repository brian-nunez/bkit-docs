---
hide:
  - toc
  - navigation
---

<div class="bkit-home">
  <section class="bkit-hero">
    <div class="bkit-hero__inner">
      <div class="bkit-hero__copy">
        <p class="bkit-kicker">Composable Go building blocks</p>
        <h1>BKit</h1>
        <p class="bkit-hero__lead">Configuration, storage, and database primitives with small APIs and explicit boundaries.</p>
        <div class="bkit-actions">
          <a class="md-button md-button--primary" href="getting-started/">Get started</a>
          <a class="md-button" href="https://github.com/brian-nunez">View on GitHub</a>
        </div>
      </div>

      <div class="bkit-system" aria-label="BKit package architecture">
        <div class="bkit-node bkit-node--app">
          <span class="bkit-node__index">00</span>
          <strong>Go service</strong>
          <small>your application</small>
        </div>
        <div class="bkit-node bkit-node--config">
          <span class="bkit-node__index">01</span>
          <strong>bconfig</strong>
          <small>files · environment</small>
        </div>
        <div class="bkit-node bkit-node--kv">
          <span class="bkit-node__index">02</span>
          <strong>bkv</strong>
          <small>local · redis · sqlite</small>
        </div>
        <div class="bkit-node bkit-node--db">
          <span class="bkit-node__index">03</span>
          <strong>bdb</strong>
          <small>sqlite · postgres · mariadb</small>
        </div>
      </div>
    </div>
  </section>

  <section class="bkit-section bkit-reveal">
    <div class="bkit-section__head">
      <div>
        <p class="bkit-section__eyebrow">The ecosystem</p>
        <h2>Use one.<br>Compose many.</h2>
      </div>
      <p>Each library owns one infrastructure concern. Install only the modules and drivers your service needs.</p>
    </div>

    <div class="bkit-packages">
      <a class="bkit-package" href="bconfig/">
        <span class="bkit-package__number">01</span>
        <strong>bconfig</strong>
        <span>Load, merge, inspect, and decode configuration.</span>
        <span class="bkit-package__arrow">→</span>
      </a>
      <a class="bkit-package" href="bkv/">
        <span class="bkit-package__number">02</span>
        <strong>bkv</strong>
        <span>One key/value interface across three backends.</span>
        <span class="bkit-package__arrow">→</span>
      </a>
      <a class="bkit-package" href="bdb/">
        <span class="bkit-package__number">03</span>
        <strong>bdb</strong>
        <span>SQL connections, queries, transactions, and pools.</span>
        <span class="bkit-package__arrow">→</span>
      </a>
    </div>
  </section>

  <section class="bkit-section bkit-reveal">
    <div class="bkit-section__head">
      <div>
        <p class="bkit-section__eyebrow">Architecture</p>
        <h2>Clear roles.<br>Loose coupling.</h2>
      </div>
      <p>The packages never require one another. Your startup code composes them while each library stays replaceable.</p>
    </div>

    <div class="bkit-flow">
      <div class="bkit-flow__step">
        <code>bconfig</code>
        <strong>Configuration</strong>
        <p>Load startup values from YAML, JSON, and environment variables.</p>
      </div>
      <span class="bkit-flow__arrow">→</span>
      <div class="bkit-flow__step">
        <code>bkv</code>
        <strong>State & cache</strong>
        <p>Keep temporary or shared string values behind one store interface.</p>
      </div>
      <span class="bkit-flow__arrow">→</span>
      <div class="bkit-flow__step">
        <code>bdb</code>
        <strong>Persistence</strong>
        <p>Work with SQL databases through standard Go concepts.</p>
      </div>
    </div>
  </section>

  <section class="bkit-section bkit-reveal">
    <div class="bkit-section__head">
      <div>
        <p class="bkit-section__eyebrow">Design principles</p>
        <h2>Small by<br>intention.</h2>
      </div>
      <p>BKit stays close to the Go standard library and keeps backend behavior visible instead of hiding it behind a framework.</p>
    </div>

    <div class="bkit-principles">
      <div class="bkit-principle">
        <span>01 / independent</span>
        <h3>Adopt incrementally</h3>
        <p>Use configuration, key/value storage, or databases independently.</p>
      </div>
      <div class="bkit-principle">
        <span>02 / explicit</span>
        <h3>Compose at startup</h3>
        <p>Select sources and drivers directly in application bootstrap code.</p>
      </div>
      <div class="bkit-principle">
        <span>03 / focused</span>
        <h3>Depend on small contracts</h3>
        <p>Interfaces cover the shared behavior without erasing backend semantics.</p>
      </div>
      <div class="bkit-principle">
        <span>04 / idiomatic</span>
        <h3>Keep Go visible</h3>
        <p>Contexts, errors, database/sql, and lifecycle ownership stay familiar.</p>
      </div>
    </div>
  </section>

  <section class="bkit-cta">
    <div class="bkit-cta__content bkit-reveal">
      <p class="bkit-kicker">Start with one package</p>
      <h2>Build the service,<br>not the scaffolding.</h2>
      <p>Choose a library, install its drivers, and keep the rest of your architecture yours.</p>
      <div class="bkit-actions">
        <a class="md-button md-button--primary" href="getting-started/">Read getting started</a>
        <a class="md-button" href="https://github.com/brian-nunez">View on GitHub</a>
      </div>
    </div>
  </section>
</div>
