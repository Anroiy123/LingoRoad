# Tổng hợp đề tài thực tập

> Sản phẩm triển khai của đề tài: **lingoRoad**. Tên này được dùng cho ứng dụng người học, giao diện và tài liệu sản phẩm; tên đề tài học thuật bên dưới được giữ nguyên.

## Tên đề tài

**Xây dựng ứng dụng học tiếng Anh cá nhân hóa với lộ trình học tự động ứng dụng trí tuệ nhân tạo**

---

## 1. Tổng quan định hướng đề tài

Đề tài tập trung vào việc nghiên cứu và xây dựng một hệ thống học tiếng Anh cá nhân hóa, trong đó ứng dụng các kỹ thuật trí tuệ nhân tạo để:

- Đánh giá trình độ tiếng Anh đầu vào của người học.
- Mô hình hóa năng lực người học theo từng kỹ năng ngôn ngữ.
- Theo dõi quá trình học tập và mức độ thành thạo theo thời gian.
- Sinh lộ trình học tự động phù hợp với mục tiêu và năng lực cá nhân.
- Sinh bài tập thích ứng theo trình độ, kỹ năng và lỗi sai của người học.
- Hỗ trợ giải thích ngữ pháp, từ vựng và lộ trình học bằng mô hình ngôn ngữ lớn.
- Đánh giá phát âm, luyện nói và hỗ trợ hội thoại tiếng Anh.
- Tích hợp cơ chế ôn tập ngắt quãng và gamification để duy trì động lực học dài hạn.

---

# 2. Nội dung lý thuyết

## 2.1. Lý thuyết học tập thích ứng và cá nhân hóa giáo dục

Nghiên cứu các nền tảng lý thuyết phục vụ cho việc cá nhân hóa quá trình học tiếng Anh, bao gồm:

- **Adaptive Learning Theory**: lý thuyết học tập thích ứng, trong đó nội dung học được điều chỉnh dựa trên năng lực và hành vi học tập của từng cá nhân.
- **Zone of Proximal Development (ZPD)**: vùng phát triển gần, dùng để lựa chọn nội dung học phù hợp với khả năng hiện tại nhưng vẫn có tính thử thách.
- **Mastery Learning**: học đến khi thành thạo, chỉ chuyển sang nội dung mới khi người học đạt ngưỡng thành thạo nhất định.
- **Self-Regulated Learning**: học tập tự điều chỉnh, trong đó người học có thể theo dõi tiến độ, đặt mục tiêu và điều chỉnh chiến lược học.
- **Spaced Repetition System (SRS)**: hệ thống ôn tập ngắt quãng, hỗ trợ ghi nhớ dài hạn trong học ngoại ngữ.

---

## 2.2. Knowledge Tracing và Learner Modeling

Nghiên cứu kỹ thuật theo dõi tri thức và mô hình hóa năng lực người học nhằm dự đoán mức độ thành thạo của từng kỹ năng ngôn ngữ theo thời gian.

Các mô hình cần tìm hiểu:

- **Deep Knowledge Tracing (DKT)**: mô hình sử dụng mạng học sâu để dự đoán khả năng trả lời đúng của người học trong tương lai.
- **DKVMN (Dynamic Key-Value Memory Networks)**: mô hình bộ nhớ động dùng để lưu trữ và cập nhật trạng thái tri thức của người học.
- **SAINT+ (Self-Attentive model for Knowledge Tracing)**: mô hình attention dùng để dự đoán kết quả học tập dựa trên chuỗi tương tác học tập.

Mục tiêu nghiên cứu:

- Theo dõi xác suất thành thạo của từng kỹ năng tiếng Anh.
- Cập nhật năng lực người học theo lịch sử làm bài.
- Dự đoán kỹ năng yếu và kỹ năng cần học tiếp theo.
- Làm cơ sở cho việc sinh lộ trình học cá nhân hóa.

---

## 2.3. Mô hình ngôn ngữ lớn và RAG trong giáo dục ngôn ngữ

Nghiên cứu về **Large Language Models (LLMs)** và kỹ thuật **Retrieval-Augmented Generation (RAG)** để ứng dụng trong giáo dục tiếng Anh.

Các hướng ứng dụng chính:

- **Personalized Learning Path Generation**: sinh lộ trình học cá nhân hóa.
- **Adaptive Exercise Generation**: sinh bài tập thích ứng theo năng lực người học.
- Giải thích ngữ pháp theo cách hiểu của từng người học.
- Trả lời câu hỏi liên quan đến nội dung học.
- Tư vấn và điều chỉnh mục tiêu học tập bằng ngôn ngữ tự nhiên.

Các mô hình được đề cập:

- Vistral-7B.
- GPT-4o.
- Llama-3.

---

## 2.4. Đánh giá trình độ tiếng Anh tự động theo CEFR

Nghiên cứu kỹ thuật **Automated Proficiency Assessment** theo khung tham chiếu châu Âu **CEFR (A1–C2)**.

Nội dung nghiên cứu:

- Phân loại trình độ tiếng Anh từ bài kiểm tra đầu vào.
- Đánh giá trình độ theo từng kỹ năng:
  - Listening.
  - Speaking.
  - Reading.
  - Writing.
  - Grammar.
  - Vocabulary.
- Ứng dụng **Item Response Theory (IRT)** để ước lượng năng lực người học.
- Xây dựng bài kiểm tra đầu vào thích ứng thay vì bài kiểm tra cố định.

---

## 2.5. Nhận dạng giọng nói và đánh giá phát âm

Nghiên cứu kỹ thuật **Automatic Speech Recognition (ASR)** và **Pronunciation Assessment**.

Các nội dung cần nghiên cứu:

- Nhận dạng giọng nói tiếng Anh bằng Whisper fine-tuned.
- Căn chỉnh âm vị bằng Montreal Forced Aligner (MFA).
- Phân tích độ chính xác âm vị.
- Phân tích trọng âm từ và trọng âm câu.
- Phân tích ngữ điệu.
- Phân tích độ trôi chảy khi nói.

Các tiêu chí đánh giá phát âm:

- **Phoneme accuracy**: độ chính xác âm vị.
- **Word stress**: trọng âm từ.
- **Sentence stress**: trọng âm câu.
- **Intonation**: ngữ điệu.
- **Fluency**: độ trôi chảy.

---

## 2.6. Tối ưu hóa lộ trình học

Nghiên cứu kỹ thuật **Learning Path Optimization** nhằm sinh lộ trình học tối ưu cho từng người học.

Cách mô hình hóa bài toán:

- Lộ trình học được xem như bài toán tối ưu hóa tổ hợp.
- Mục tiêu là tối thiểu hóa thời gian đạt được trình độ mong muốn.
- Trạng thái người học thay đổi sau mỗi lần học hoặc làm bài.

Các thuật toán được đề cập:

- **Greedy Algorithm**: thuật toán tham lam.
- **Dynamic Programming**: quy hoạch động.
- **Reinforcement Learning**:
  - DQN.
  - PPO.

Mục tiêu:

- Chọn bài học hoặc kỹ năng tiếp theo phù hợp nhất.
- Cân bằng giữa học kiến thức mới và ôn tập kiến thức cũ.
- Tối ưu thời gian đạt mục tiêu CEFR.

---

## 2.7. Gamification trong giáo dục

Nghiên cứu kỹ thuật **Educational Gamification** nhằm tăng động lực học tập lâu dài.

Các thành phần gamification:

- Hệ thống điểm.
- Huy hiệu.
- Bảng xếp hạng.
- Streak học tập.
- Nhiệm vụ hằng ngày.
- Cấp độ người học.

Cơ sở lý thuyết:

- Tâm lý học hành vi.
- Duy trì động lực học tập.
- Tạo thói quen học ngoại ngữ dài hạn.

---

## 2.8. Công nghệ lập trình và cơ sở dữ liệu

Tìm hiểu và sử dụng các công nghệ sau:

### Python

Dùng cho:

- Xây dựng mô hình học máy.
- Xử lý dữ liệu.
- Huấn luyện và thử nghiệm mô hình AI.
- Xây dựng API AI service.

### ReactJS

Dùng cho:

- Xây dựng giao diện website.
- Hiển thị bài học, bài kiểm tra, lộ trình học.
- Hiển thị dashboard tiến độ học tập.

### PostgreSQL

Dùng cho:

- Lưu thông tin người học.
- Lưu ngân hàng câu hỏi.
- Lưu lịch sử làm bài.
- Lưu trạng thái năng lực người học.
- Lưu lộ trình học cá nhân hóa.

---

# 3. Nội dung thực hành

## 3.1. Các nhiệm vụ liên quan đến trí tuệ nhân tạo

---

## 3.1.1. Xây dựng module đánh giá trình độ đầu vào

### a. Thu thập và xây dựng ngân hàng câu hỏi

Nguồn dữ liệu được đề cập:

- **CEFR-SP Dataset**.
- **RACE Dataset**.

Yêu cầu:

- Xây dựng ngân hàng câu hỏi kiểm tra trình độ tiếng Anh.
- Phân loại tối thiểu **500+ câu hỏi**.
- Gán nhãn theo **6 cấp độ CEFR**:
  - A1.
  - A2.
  - B1.
  - B2.
  - C1.
  - C2.
- Gán nhãn theo **5 kỹ năng**:
  - Grammar.
  - Vocabulary.
  - Reading.
  - Listening.
  - Writing.
- Gán nhãn tham số theo lý thuyết IRT:
  - Độ khó `b`.
  - Độ phân biệt `a`.

---

### b. Xây dựng Computerized Adaptive Testing dựa trên IRT

Yêu cầu:

- Xây dựng và tinh chỉnh mô hình **Computerized Adaptive Testing (CAT)**.
- Ứng dụng **IRT 3-Parameter Logistic Model**.
- Thuật toán lựa chọn câu hỏi tự động dựa trên năng lực ước tính hiện tại.
- Sử dụng tiêu chí **Maximum Information** để chọn câu hỏi phù hợp.
- Giảm số câu kiểm tra còn **20–30 câu** thay vì 100 câu cố định.
- Mục tiêu kỳ vọng: đạt độ chính xác phân loại CEFR trên 88% so với bài kiểm tra chuẩn Cambridge.

---

### c. Xây dựng module đánh giá kỹ năng nói

Pipeline được đề xuất:

1. Tích hợp Whisper ASR để nhận dạng câu trả lời.
2. Sử dụng Montreal Forced Aligner để căn chỉnh âm vị.
3. Fine-tune mô hình phân loại phát âm trên SpeechOcean762.
4. Đánh giá các khía cạnh phát âm:
   - Độ chính xác âm vị.
   - Trọng âm.
   - Ngữ điệu.

Các chiều đánh giá:

- Accuracy.
- Fluency.
- Prosody.
- Completeness.
- Total score.

---

## 3.1.2. Xây dựng module theo dõi tri thức và mô hình hóa người học

### a. Tiền xử lý dữ liệu và xây dựng pipeline đặc trưng

Nguồn dữ liệu được đề cập:

- **EdNet Dataset**.
- **Duolingo SLAM Dataset**.

Yêu cầu:

- Tiền xử lý dữ liệu tương tác học tập.
- Xây dựng pipeline trích xuất đặc trưng.

Các nhóm đặc trưng:

#### Đặc trưng tương tác

- Response time.
- Correctness.
- Attempt count.
- Hint usage.

#### Đặc trưng câu hỏi

- Difficulty.
- Skill tags.
- CEFR level.

#### Đặc trưng thời gian

- Time since last attempt.
- Forgetting curve features.

---

### b. Xây dựng mô hình Knowledge Tracing

Yêu cầu:

- Xây dựng và tinh chỉnh mô hình **Deep Knowledge Tracing (DKT)**.
- Nâng cao bằng mô hình **SAINT+**.
- Huấn luyện trên EdNet Dataset.
- Dự đoán xác suất người học trả lời đúng câu hỏi tiếp theo cho từng kỹ năng ngôn ngữ.
- Mục tiêu kỳ vọng: AUC-ROC trên 0.82 trên EdNet test set.
- So sánh hiệu năng với:
  - DKT-LSTM.
  - DKVMN baseline.

---

### c. Xây dựng Knowledge Graph kỹ năng tiếng Anh

Yêu cầu:

- Định nghĩa **150+ kỹ năng con**.
- Tổ chức kỹ năng theo cấu trúc phân cấp.

Ví dụ cấu trúc:

```text
Grammar
└── Tenses
    └── Present Perfect
        └── Usage in Context
```

Yêu cầu khác:

- Xác định quan hệ tiên quyết giữa các kỹ năng.
- Theo dõi mức độ thành thạo từng kỹ năng con theo thời gian học thực tế.
- Kết hợp với mô hình DKT để cập nhật trạng thái tri thức người học.

---

## 3.1.3. Xây dựng module sinh lộ trình học cá nhân hóa

### a. Xây dựng hệ thống sinh lộ trình học bằng Deep Q-Network

Yêu cầu:

- Xây dựng hệ thống sinh lộ trình học tự động bằng **Deep Q-Network (DQN)**.
- Mô hình hóa bài toán dưới dạng **Markov Decision Process (MDP)**.

Các thành phần của MDP:

#### State

Vector năng lực người học theo **150 kỹ năng con**.

#### Action

Lựa chọn bài học hoặc kỹ năng tiếp theo.

#### Reward

Mức cải thiện năng lực thực tế sau mỗi bài học.

Yêu cầu thử nghiệm:

- Huấn luyện DQN trên môi trường mô phỏng từ dữ liệu EdNet.
- So sánh lộ trình do DQN sinh ra với lộ trình cố định theo chương trình chuẩn.
- Mục tiêu kỳ vọng: cải thiện 35% thời gian đạt mục tiêu CEFR theo mô phỏng.

---

### b. Tích hợp Spaced Repetition System

Yêu cầu:

- Tích hợp thuật toán ôn tập ngắt quãng.
- Các thuật toán được đề cập:
  - SuperMemo SM-2.
  - FSRS - Free Spaced Repetition Scheduler.

Nội dung cần thực hiện:

- Lập lịch ôn tập từ vựng và ngữ pháp cá nhân hóa.
- Tính toán khoảng cách ôn tập tối ưu.
- Cập nhật **ease factor** sau mỗi lần ôn tập.
- Mô hình hóa đường cong quên lãng Ebbinghaus cho từng người học.

---

### c. Xây dựng LLM-based Learning Path Advisor

Yêu cầu:

- Tích hợp mô hình ngôn ngữ lớn với RAG.
- Mô hình được đề cập:
  - Vistral-7B.
  - GPT-4o.

Nguồn tri thức RAG:

- Giáo trình tiếng Anh.
- Bài tập mẫu.
- Hướng dẫn ngữ pháp.
- Tài liệu học ngoại ngữ.

Chức năng:

- Sinh giải thích lộ trình học bằng tiếng Việt.
- Trả lời câu hỏi của người học về lộ trình.
- Điều chỉnh mục tiêu học tập theo yêu cầu người dùng.

Ví dụ câu giải thích:

> “Tại sao bạn cần học kỹ năng này tiếp theo?”

---

## 3.1.4. Xây dựng module sinh bài tập thích ứng

### a. Sinh bài tập cá nhân hóa theo trình độ

Yêu cầu:

- Xây dựng và tinh chỉnh mô hình sinh bài tập cá nhân hóa.
- Mô hình được đề cập:
  - Llama-3.
  - Vistral.

Nguồn dữ liệu:

- RACE Dataset.
- Cambridge Learner Corpus.

Các dạng bài tập cần sinh:

- Câu hỏi trắc nghiệm.
- Bài tập điền từ.
- Bài tập viết lại câu.
- Đoạn hội thoại.
- Bài tập theo đúng cấp độ CEFR.
- Bài tập theo kỹ năng mục tiêu của người học.

Tiêu chí đánh giá:

- BLEU.
- ROUGE.
- Đánh giá chuyên gia ngôn ngữ.
- Mục tiêu kỳ vọng: trên 4.2/5 điểm.

---

### b. Sinh phương án nhiễu chất lượng cao

Yêu cầu:

- Xây dựng module sinh phương án nhiễu cho bài tập từ vựng và ngữ pháp.
- Sử dụng:
  - Word2Vec.
  - FastText embedding.
  - WordNet.

Mục tiêu:

- Tìm từ gần nghĩa nhưng sai ngữ cảnh.
- Sinh phương án nhiễu hợp lý.
- Đảm bảo phương án nhiễu phù hợp với lỗi sai phổ biến của người Việt học tiếng Anh.
- Tham khảo lỗi sai từ **EFCAMDAT Dataset**.

---

### c. Xây dựng Automated Writing Evaluation

Yêu cầu:

- Xây dựng module đánh giá bài viết tiếng Anh tự động.
- Fine-tune mô hình trên **TOEFL11 Dataset**.

Các tiêu chí đánh giá bài viết:

- Task Achievement.
- Coherence & Cohesion.
- Lexical Resource.
- Grammatical Accuracy.

Chức năng:

- Sinh phản hồi chi tiết bằng tiếng Việt.
- Chỉ ra lỗi cụ thể.
- Gợi ý sửa cho từng câu.

---

## 3.1.5. Xây dựng module đánh giá phát âm và luyện nói

### a. Pipeline đánh giá phát âm toàn diện

Pipeline được đề xuất:

1. Whisper ASR nhận dạng giọng nói.
2. MFA căn chỉnh ở mức phoneme.
3. Trích xuất đặc trưng âm học.
4. Mô hình GOP scoring đánh giá phát âm.

Các đặc trưng âm học:

- MFCC.
- Pitch.
- Energy.

Nguồn dữ liệu:

- L2-ARCTIC Dataset.
- SpeechOcean762.

Yêu cầu đánh giá:

- Phát hiện lỗi phát âm cụ thể theo âm vị.
- Định vị lỗi phát âm trong câu nói.
- Chấm điểm phát âm bằng Goodness of Pronunciation.

Ví dụ lỗi phát âm của người Việt:

- Âm `/th/` bị phát âm thành `/d/` hoặc `/t/`.

---

### b. Xây dựng AI conversation partner

Yêu cầu ban đầu được đề cập:

- Xây dựng AI conversation partner bằng LLMs.
- Tích hợp:
  - ASR.
  - TTS.
- Mục tiêu: chatbot luyện hội thoại tiếng Anh.

> **Ghi chú:** Phần nội dung thầy gửi bị dừng ở đoạn “chatbot luyện hội...”, nên các yêu cầu chi tiết phía sau của module này chưa đầy đủ.

---

# 4. Các dataset được đề cập

| Dataset                  | Mục đích sử dụng                                              |
| ------------------------ | ------------------------------------------------------------- |
| CEFR-SP Dataset          | Xây dựng câu hỏi và phân loại trình độ CEFR                   |
| RACE Dataset             | Xây dựng bài đọc hiểu và câu hỏi tiếng Anh                    |
| SpeechOcean762           | Đánh giá phát âm và speaking assessment                       |
| EdNet Dataset            | Knowledge Tracing, mô hình hóa tương tác học tập              |
| Duolingo SLAM Dataset    | Theo dõi lỗi học ngoại ngữ và đặc trưng tương tác             |
| Cambridge Learner Corpus | Sinh bài tập và phân tích lỗi người học                       |
| EFCAMDAT Dataset         | Phân tích lỗi sai phổ biến của người học tiếng Anh            |
| TOEFL11 Dataset          | Đánh giá bài viết tiếng Anh tự động                           |
| L2-ARCTIC Dataset        | Đánh giá phát âm của người học tiếng Anh như ngôn ngữ thứ hai |

---

# 5. Các mô hình và kỹ thuật được đề cập

## 5.1. Đánh giá trình độ

- CEFR.
- IRT.
- IRT 3-Parameter Logistic Model.
- Computerized Adaptive Testing.
- Maximum Information Criterion.

## 5.2. Knowledge Tracing

- DKT.
- DKT-LSTM.
- DKVMN.
- SAINT+.

## 5.3. Sinh nội dung và tư vấn học tập

- LLMs.
- RAG.
- GPT-4o.
- Vistral-7B.
- Llama-3.

## 5.4. Tối ưu hóa lộ trình

- Greedy Algorithm.
- Dynamic Programming.
- Reinforcement Learning.
- DQN.
- PPO.
- Markov Decision Process.

## 5.5. Ôn tập ngắt quãng

- Spaced Repetition System.
- SuperMemo SM-2.
- FSRS.
- Ebbinghaus Forgetting Curve.

## 5.6. Đánh giá phát âm

- Whisper ASR.
- Whisper fine-tuning.
- Montreal Forced Aligner.
- GOP scoring.
- MFCC.
- Pitch.
- Energy.
- Phoneme accuracy.
- Prosody.
- Fluency.

## 5.7. Sinh phương án nhiễu

- Word2Vec.
- FastText.
- WordNet.
- Distractor generation.

## 5.8. Gamification

- Points.
- Badges.
- Leaderboard.
- Streak.
- Behavioral psychology.

---

# 6. Công nghệ triển khai

| Công nghệ                   | Vai trò                                               |
| --------------------------- | ----------------------------------------------------- |
| Python                      | Xây dựng mô hình học máy, xử lý dữ liệu, backend AI   |
| ReactJS                     | Xây dựng giao diện website                            |
| PostgreSQL                  | Lưu trữ dữ liệu người học, câu hỏi, kết quả, lộ trình |
| LLM API / Local LLM         | Sinh bài tập, giải thích, tư vấn học tập              |
| Vector Database / RAG Store | Lưu tài liệu phục vụ truy xuất tri thức               |
| ASR / TTS                   | Luyện nói và hội thoại tiếng Anh                      |

---

# 7. Đầu ra kỳ vọng của đề tài

Hệ thống sau khi hoàn thành dự kiến có các chức năng chính:

1. Người học đăng ký tài khoản và khai báo mục tiêu học tiếng Anh.
2. Người học làm bài kiểm tra đầu vào thích ứng.
3. Hệ thống xác định trình độ CEFR theo từng kỹ năng.
4. Hệ thống xây dựng hồ sơ năng lực người học.
5. Hệ thống sinh lộ trình học cá nhân hóa.
6. Người học làm bài tập theo lộ trình.
7. Hệ thống cập nhật mức độ thành thạo từng kỹ năng.
8. Hệ thống tự động điều chỉnh bài học tiếp theo.
9. Hệ thống sinh bài tập thích ứng bằng AI.
10. Hệ thống giải thích ngữ pháp và lỗi sai bằng tiếng Việt.
11. Hệ thống nhắc ôn tập theo SRS.
12. Hệ thống có gamification để duy trì động lực học.
13. Hệ thống có thể mở rộng sang luyện nói và đánh giá phát âm.

---

# 8. Ghi chú tổng hợp

Đề tài có phạm vi rất rộng, bao gồm nhiều mảng lớn:

- Adaptive Learning.
- Knowledge Tracing.
- Learning Path Optimization.
- Large Language Models.
- RAG.
- CEFR Assessment.
- Pronunciation Assessment.
- Automated Writing Evaluation.
- Spaced Repetition.
- Gamification.
- Full-stack Web/App Development.

Trong quá trình triển khai thực tập, nên chia nội dung thành:

## Phần bắt buộc nên làm

- Placement Test.
- Learner Modeling cơ bản.
- Skill Graph.
- Learning Path Generation.
- Adaptive Exercise Generation.
- Dashboard học tập.
- Lưu trữ dữ liệu bằng PostgreSQL.
- Giao diện bằng ReactJS.

## Phần nâng cao nếu còn thời gian

- DKT / SAINT+ thử nghiệm offline.
- DQN / PPO mô phỏng sinh lộ trình.
- Whisper ASR cho luyện nói.
- MFA phoneme-level alignment.
- Automated Writing Evaluation.
- Fine-tuning LLM.
- Fine-tuning mô hình đánh giá phát âm.

---

# 9. Tóm tắt một câu

Đề tài hướng tới xây dựng một hệ thống học tiếng Anh thông minh, có khả năng đánh giá trình độ, theo dõi năng lực, sinh lộ trình học cá nhân hóa, tạo bài tập thích ứng và hỗ trợ luyện tập bằng AI nhằm tối ưu hóa quá trình học ngoại ngữ dài hạn.
