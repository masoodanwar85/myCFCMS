
<style>
.wc-pricing {
  --wc-navy: #183451;
  --wc-blue: #eaf3fc;
  --wc-green: #087a50;
  --wc-green-light: #eaf8f0;
  --wc-border: #dce5ee;
  --wc-text: #24354a;
  font-family: inherit;
  color: var(--wc-text);
  max-width: 1200px;
  margin: 40px auto;
}

.wc-pricing * {
  box-sizing: border-box;
}

.wc-pricing .wc-heading {
  margin-bottom: 24px;
}

.wc-pricing .wc-heading h2 {
  font-size: clamp(26px, 3vw, 36px);
  color: var(--wc-navy);
  margin: 0 0 12px;
  line-height: 1.2;
}

.wc-pricing .wc-heading p {
  color: #63758a;
  margin: 0;
  font-size: 16px;
}

.wc-pricing .wc-summary {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 30px;
}

.wc-pricing .wc-summary-card {
  background: #f2f7fc;
  border: 1px solid var(--wc-border);
  border-radius: 12px;
  padding: 24px;
}

.wc-pricing .wc-summary-card.featured {
  background: var(--wc-green-light);
  border-color: #b7e4cd;
}

.wc-pricing .wc-card-label {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 12px;
}

.wc-pricing .wc-card-value {
  font-size: 32px;
  font-weight: 750;
  line-height: 1.1;
  color: var(--wc-navy);
}

.wc-pricing .featured .wc-card-value {
  color: var(--wc-green);
}

.wc-pricing .wc-card-note {
  margin-top: 10px;
  font-size: 13px;
  color: #607185;
}

.wc-pricing .wc-table-wrap {
  overflow-x: auto;
  border: 1px solid var(--wc-border);
  border-radius: 12px;
  margin-bottom: 28px;
  -webkit-overflow-scrolling: touch;
}

.wc-pricing table {
  width: 100%;
  min-width: 760px;
  border-collapse: separate;
  border-spacing: 0;
  margin: 0;
  font-size: 14px;
}

.wc-pricing th {
  background: var(--wc-navy);
  color: #fff;
  font-weight: 600;
  text-align: left;
  padding: 17px 16px;
  vertical-align: middle;
  line-height: 1.5;
}

.wc-pricing td {
  padding: 17px 16px;
  border-bottom: 1px solid var(--wc-border);
  background: #fff;
  vertical-align: middle;
}

.wc-pricing tbody tr:nth-child(even) td {
  background: #f7f9fc;
}

.wc-pricing tbody tr:last-child td {
  border-bottom: none;
}

.wc-pricing .wc-highlight {
  background: var(--wc-green-light) !important;
  color: var(--wc-green);
  font-weight: 700;
}

.wc-pricing th.wc-highlight {
  background: #d4f1e1 !important;
  color: #086844;
}

.wc-pricing .wc-total {
  font-weight: 750;
  color: var(--wc-navy);
  background: var(--wc-blue) !important;
}

.wc-pricing .wc-savings {
  display: inline-block;
  padding: 5px 10px;
  border-radius: 20px;
  background: #d4f1e1;
  color: #086844;
  font-weight: 700;
  font-size: 12px;
}

.wc-pricing .wc-note {
  font-size: 13px;
  color: #687b90;
  line-height: 1.7;
  margin-top: 15px;
}

.wc-pricing .wc-benefits {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  padding: 24px 0;
  border-top: 1px solid var(--wc-border);
  margin-top: 25px;
}

.wc-pricing .wc-benefit strong {
  display: block;
  color: var(--wc-navy);
  margin-bottom: 6px;
}

.wc-pricing .wc-benefit span {
  color: #63758a;
  font-size: 13px;
}

@media (max-width: 768px) {
  .wc-pricing {
    margin: 24px auto;
  }

  .wc-pricing .wc-summary {
    grid-template-columns: 1fr;
    gap: 10px;
  }

  .wc-pricing .wc-summary-card {
    padding: 18px;
  }

  .wc-pricing .wc-benefits {
    grid-template-columns: repeat(2, 1fr);
  }

  .wc-pricing th,
  .wc-pricing td {
    padding: 13px 12px;
  }
}

@media (max-width: 480px) {
  .wc-pricing .wc-benefits {
    grid-template-columns: 1fr;
  }
}
</style>

<section class="wc-pricing">

  <div class="wc-heading">
    <h2>Transparent Probate Fees</h2>
    <p>
      Understand the costs involved in applying for
      probate in New South Wales.
    </p>
  </div>

  <div class="wc-summary">
    <div class="wc-summary-card">
      <div class="wc-card-label">Regulated solicitor fee</div>
      <div class="wc-card-value">From $560</div>
      <div class="wc-card-note">Excluding GST</div>
    </div>

    <div class="wc-summary-card featured">
      <div class="wc-card-label">Our professional fee</div>
      <div class="wc-card-value">From $504</div>
      <div class="wc-card-note">
        <span class="wc-savings">Save 10%</span>
        on professional fees
      </div>
    </div>

    <div class="wc-summary-card">
      <div class="wc-card-label">Court filing fees</div>
      <div class="wc-card-value">Estate-based</div>
      <div class="wc-card-note">
        Set by the Supreme Court of NSW
      </div>
    </div>
  </div>

  <div class="wc-heading">
    <h2>Solicitor Professional Fees</h2>
    <p>Comparison of regulated fees and our discounted fees.</p>
  </div>

  <div class="wc-table-wrap" role="region"
       aria-label="Probate professional fee comparison"
       tabindex="0">
    <table>
      <thead>
        <tr>
          <th scope="col">Gross Estate Value</th>
          <th scope="col">Regulated Fee</th>
          <th scope="col" class="wc-highlight">
            Our Professional Fee
          </th>
          <th scope="col">Your Savings</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Up to $30,000</td>
          <td>$560</td>
          <td class="wc-highlight">$504</td>
          <td><span class="wc-savings">$56</span></td>
        </tr>
        <tr>
          <td>$30,001 – $150,000</td>
          <td>$960</td>
          <td class="wc-highlight">$864</td>
          <td><span class="wc-savings">$96</span></td>
        </tr>
        <tr>
          <td>$150,001 – $1,000,000</td>
          <td>$1,670</td>
          <td class="wc-highlight">$1,503</td>
          <td><span class="wc-savings">$167</span></td>
        </tr>
        <tr>
          <td>$1,000,001 – $3,000,000</td>
          <td>$5,470</td>
          <td class="wc-highlight">$4,923</td>
          <td><span class="wc-savings">$547</span></td>
        </tr>
        <tr>
          <td>$3,000,001 – $5,000,000</td>
          <td>$8,800</td>
          <td class="wc-highlight">$7,920</td>
          <td><span class="wc-savings">$880</span></td>
        </tr>
        <tr>
          <td>$5,000,001 – $10,000,000</td>
          <td>$11,000</td>
          <td class="wc-highlight">$9,900</td>
          <td><span class="wc-savings">$1,100</span></td>
        </tr>
        <tr>
          <td>Over $10,000,000</td>
          <td>$15,500</td>
          <td class="wc-highlight">$13,950</td>
          <td><span class="wc-savings">$1,550</span></td>
        </tr>
      </tbody>
    </table>
  </div>

  <p class="wc-note">
    Professional fees shown are illustrative figures,
    excluding GST and disbursements. Actual fees depend
    on the applicable regulated scale and estate value.
  </p>

  <div class="wc-heading" style="margin-top:40px">
    <h2>Supreme Court Filing Fees</h2>
    <p>
      Court fees are payable separately and are not
      included in our professional fees.
    </p>
  </div>

  <div class="wc-table-wrap" role="region"
       aria-label="Supreme Court filing fees"
       tabindex="0">
    <table>
      <thead>
        <tr>
          <th scope="col">Gross Estate Value</th>
          <th scope="col">Court Filing Fee</th>
        </tr>
      </thead>
      <tbody>
        <tr><td>Less than $100,000</td><td>$0</td></tr>
        <tr><td>$100,000 – $249,999</td><td>$960</td></tr>
        <tr><td>$250,000 – $499,999</td><td>$1,303</td></tr>
        <tr><td>$500,000 – $999,999</td><td>$1,999</td></tr>
        <tr><td>$1,000,000 – $1,999,999</td><td>$2,663</td></tr>
        <tr><td>$2,000,000 – $4,999,999</td><td>$4,439</td></tr>
        <tr><td>$5,000,000 or more</td><td>$7,399</td></tr>
      </tbody>
    </table>
  </div>

  <div class="wc-benefits">
    <div class="wc-benefit">
      <strong>10% Savings</strong>
      <span>Discounted professional fees</span>
    </div>
    <div class="wc-benefit">
      <strong>Transparent Pricing</strong>
      <span>Understand your costs upfront</span>
    </div>
    <div class="wc-benefit">
      <strong>Clear Fee Breakdown</strong>
      <span>Professional and court fees separated</span>
    </div>
    <div class="wc-benefit">
      <strong>Professional Support</strong>
      <span>Guidance through the probate process</span>
    </div>
  </div>

  <p class="wc-note">
    Important: Confirm current NSW regulated professional
    fees, Supreme Court filing fees, applicable GST and
    estate-value thresholds before publishing.
  </p>

</section>
